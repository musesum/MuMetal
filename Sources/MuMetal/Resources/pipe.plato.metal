//  Created by warren on 2/28/23.
//  Copyright © 2023 com.deepmuse. All rights reserved.

#include <metal_stdlib>
using namespace metal;

struct PlatoVertex {
    float4 position [[ position ]];
    float4 texCoords;
    float4 color;
};

struct PlatoUniforms {
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


vertex PlatoVertex platoVertex
(
 device Vert01 const*   vert01    [[ buffer(0) ]],
 constant PlatoUniforms &uniforms [[ buffer(1) ]],
 uint32_t vid                     [[ vertex_id ]])
{
    float4 p0    = vert01[vid].p0;
    float4 p1    = vert01[vid].p1;
    //float4 extra = vert01[vid].extra; // used for debugging
    float4 color = vert01[vid].color;
    float4 n0    = vert01[vid].n0;
    float4 n1    = vert01[vid].n1;

    float r1 = uniforms.range01.x;

    float4 pos  = float4((p0 + (p1 - p0) * r1).xyz, 1);
    float4 norm = float4((n0 + (n1 - n0) * r1).xyz, 0);

    float4 camPos = uniforms.worldCamera;
    float4 worldPos = uniforms.identity * pos;
    float4 worldNorm = normalize(uniforms.inverse * norm);
    float4 eyeDirection = normalize(worldPos - camPos);

    PlatoVertex outVert;
    outVert.position = uniforms.projectModel * pos;
    outVert.texCoords = reflect(eyeDirection, worldNorm);
    outVert.color = float4(color.xyz,1);

    return outVert;
}
/// texturecube has index to a texture2d
/// vert.color is used for creating a shadow mixed texture2d's color
fragment half4 cubeIndexFragment
(
 PlatoVertex          vert        [[ stage_in   ]],
 texturecube<int16_t> cubeTex     [[ texture(0) ]],
 texture2d<half>      imageTex    [[ texture(1) ]],
 sampler              cubeSamplr  [[ sampler(0) ]],
 sampler              imageSamplr [[ sampler(1) ]])
{
    float3 cubeCoords = float3(vert.texCoords.x,
                               vert.texCoords.y,
                               -vert.texCoords.z);

    short4 index = cubeTex.sample(cubeSamplr, cubeCoords);
    float2 texCoords = float2(index.xy) / float(imageTex.get_width());
    const half4 s = imageTex.sample(imageSamplr, texCoords);

    const half4 c = half4(vert.color);
    const half4 reflect = (s*2 + c) / 2;
    return reflect;
}

/// texturecube has color information uploaded to it
/// vert.color is used for creating a shadow mixed with cube's color
fragment half4 cubeColorFragment
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

/// no cubemap, color is contained within vert.color
fragment half4 colorFragment
(
 PlatoVertex vert [[ stage_in ]])
{
    const half4 c = half4(vert.color);
    const half4 color = half4(c.xyz,1);
    return color;
}

