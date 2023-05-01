//  Created by warren on 2/28/23.
//  Copyright © 2023 com.deepmuse. All rights reserved.

#include <metal_stdlib>
using namespace metal;

struct PlatoVertex {
    float4 position [[ position ]];
    float4 texCoords;
    float4 color;
};

struct MetUniforms {
    float4x4 identity;
    float4x4 inverse; // of identity
    float4x4 projectModel;
    float4   worldCamera;
    float4   range01;
};


// index ranged  0...1
struct Vert01 {
    float4 p0 [[attribute(0)]]; // Point at 0
    float4 p1 [[attribute(1)]]; // Point at 1
    float4 extra [[attribute(5)]]; // debugging
    float4 color [[attribute(4)]];
    float4 n0 [[attribute(2)]]; // Normal at 0
    float4 n1 [[attribute(3)]]; // Normal at 1
};


vertex PlatoVertex plato
(
 device Vert01 const*           vert01   [[ buffer(0) ]],
 constant MetUniforms&          uniforms [[ buffer(1) ]],
 uint32_t vid                            [[ vertex_id ]])
{
    float range = uniforms.range01.x;
    float harmox = uniforms.range01.y;

    // each vertex triplet  012,345,678 ...
    uint i3 = vid / 3;     // 0,1,2 ...
    uint i0 = i3 * 3;      // 0,3,6 ...
    uint i1 = i0 + 1;        // 1,4,7 ...
    uint i2 = i0 + 2;        // 2,3,8 ...
    float fid = vert01[vid].extra.y;


    float3 p00 = vert01[i0].p0.xyz;
    float3 p01 = vert01[i0].p1.xyz;
    float3 p0  = p00 + (p01 - p00) * range;

    float3 p10 = vert01[i1].p0.xyz;
    float3 p11 = vert01[i1].p1.xyz;
    float3 p1  = p10 + (p11 - p10) * range;

    float3 p20 = vert01[i2].p0.xyz;
    float3 p21 = vert01[i2].p1.xyz;
    float3 p2  = p20 + (p21 - p20) * range;

    float3 v10 = p1 - p0;
    float3 v20 = p2 - p0;

    float4 pv0 = vert01[vid].p0;
    float4 pv1 = vert01[vid].p1;

    float4 pos = float4((pv0 + (pv1 - pv0) * range).xyz, 1);
    float4 norm = float4(cross(v10, v20), 0);

    float4 camPos = uniforms.worldCamera;
    float4 worldPos = uniforms.identity * pos;
    float4 worldNorm = normalize(uniforms.inverse * norm);
    float4 eyeDirection = normalize(worldPos - camPos);

    PlatoVertex outVert;
    outVert.position = uniforms.projectModel * pos;
    outVert.texCoords = reflect(eyeDirection, worldNorm);
    outVert.color = float4(fid,uniforms.range01.zw,0);

    return outVert;
}
/// texturecube has index to a texture2d
/// vert.color is used for creating a shadow mixed texture2d's color
fragment half4 platoCubeIndex
(
 PlatoVertex        vert        [[ stage_in   ]],
 texturecube<half>  cubeTex     [[ texture(0) ]],
 texture2d<half>    inTex       [[ texture(1) ]],
 texture2d<half>    palTex      [[ texture(2) ]],
 sampler            cubeSamplr  [[ sampler(0) ]],
 sampler            inSamplr    [[ sampler(1) ]],
 sampler            palSamplr   [[ sampler(2) ]])
{
    float3 cubeCoords = float3(vert.texCoords.x,
                               vert.texCoords.y,
                               -vert.texCoords.z);

    float vertIndex = vert.color.x;
    float palStride = vert.color.y;
    float mixAlpha = vert.color.z;
    uint palIndex = uint(vertIndex * palStride * 256) % 256;
    half4 palette = palTex.read(uint2(palIndex,0));

    half4 cubeIndex = cubeTex.sample(cubeSamplr, cubeCoords);
    float2 texCoords = float2(cubeIndex.xy);
    const half4 reflect = inTex.sample(inSamplr, texCoords);

    const half4 mix = (reflect * mixAlpha) + palette * (1.0-mixAlpha);
    return mix;
}

/// texturecube has color information uploaded to it
/// vert.color is used for creating a shadow mixed with cube's color
fragment half4 platoCubeColor
(
 PlatoVertex       vert    [[ stage_in   ]],
 texturecube<half> cubeTex [[ texture(0) ]],
 sampler           samplr  [[ sampler(0) ]])
{
    float3 cubeCoords = float3(vert.texCoords.x,
                               vert.texCoords.y,
                               -vert.texCoords.z);

    const half4 s = cubeTex.sample(samplr, cubeCoords);
    const half4 c = half4(vert.color);
    const half4 reflect = (s*2 + c) / 2;
    return reflect;
}

/// no cubemap, color is contained within PlatoVertex.color
fragment half4 platoColor
(
 PlatoVertex vert [[ stage_in ]])
{
    const half4 c = half4(vert.color);
    const half4 color = half4(c.xyz,1);
    return color;
}

