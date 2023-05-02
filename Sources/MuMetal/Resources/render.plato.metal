//  Created by warren on 2/28/23.
//  Copyright © 2023 com.deepmuse. All rights reserved.

#include <metal_stdlib>
using namespace metal;

struct PlatoVertex {
    float4 position [[ position ]];
    float4 texCoords;
    float4 color;
    float4 shade;
};

struct MetUniforms {
    float4x4 identity;
    float4x4 inverse; // of identity
    float4x4 projectModel;
    float4   worldCamera;
    float4   range01;
    float4   shadow;
};


// index ranged  0...1
struct Vert01 {
    float4 p0 [[attribute(0)]]; // Point at 0
    float4 p1 [[attribute(1)]]; // Point at 1
    float4 extra [[attribute(5)]]; // debugging
};

vertex PlatoVertex plato
(
 device Vert01 const*  vert01   [[ buffer(0) ]],
 constant MetUniforms& uniforms [[ buffer(1) ]],
 uint32_t vid                   [[ vertex_id ]])
{
    float faceId   = vert01[vid].extra.y; // shared by 3 vertices
    float harmonif = uniforms.range01.y;  // 0.9...1.1 ^ harmonic concave to convex
    float range    = uniforms.range01.x;     // 0...1 maps pv0...pv1

    // each vertex triplet  012,345,678 ...
    uint i3 = vid / 3;     // 0,1,2 ...
    uint i0 = i3 * 3;      // 0,3,6 ...
    uint i1 = i0 + 1;      // 1,4,7 ...
    uint i2 = i0 + 2;      // 2,3,8 ...

    // calculate 3 points of triangle face

    float3 p00 = vert01[i0].p0.xyz;
    float3 p01 = vert01[i0].p1.xyz;
    float h0 = pow(harmonif,vert01[i0].extra.z);
    float3 p0  = (p00 + (p01 - p00) * range) * h0;

    float3 p10 = vert01[i1].p0.xyz;
    float3 p11 = vert01[i1].p1.xyz;
    float h1 = pow(harmonif,vert01[i1].extra.z);
    float3 p1  = (p10 + (p11 - p10) * range) * h1;

    float3 p20 = vert01[i2].p0.xyz;
    float3 p21 = vert01[i2].p1.xyz;
    float h2 = pow(harmonif,vert01[i2].extra.z);
    float3 p2 = (p20 + (p21 - p20) * range) * h2;

    // calculate normal of face

    float3 v10 = p1 - p0;
    float3 v20 = p2 - p0;
    float4 norm = float4(cross(v10, v20), 0);

    // deterimine which of p0,p1,p2 is my pos.
    float4 pos; // my position
    float harmonic;
    switch (vid % 3) {
    case 0:  pos = float4(p0,1); harmonic = vert01[i0].extra.z; break;
    case 1:  pos = float4(p1,1); harmonic = vert01[i1].extra.z; break;
    default: pos = float4(p2,1); harmonic = vert01[i2].extra.z; break;
    }

    float4 camPos = uniforms.worldCamera;
    float4 worldPos = uniforms.identity * pos;
    float4 worldNorm = normalize(uniforms.inverse * norm);
    float4 eyeDirection = normalize(worldPos - camPos);

    PlatoVertex outVert;
    outVert.position = uniforms.projectModel * pos;
    outVert.texCoords = reflect(eyeDirection, worldNorm);
    outVert.color = float4(faceId,uniforms.range01.zw,0);
    outVert.shade = float4(uniforms.shadow.x,
                           uniforms.shadow.y,
                           harmonic, 0);

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

    uint vertIndex = uint(vert.color.x);
    uint palColors = uint(vert.color.y) % 255 + 1;
    float mixAlpha = vert.color.z;

    float pali = float(vertIndex % (palColors+1));
    float2 palIndex = float2(pali/255, 0);
    half4 palette = palTex.sample(palSamplr, palIndex);

    half4 cubeIndex = cubeTex.sample(cubeSamplr, cubeCoords);
    half4 reflect = inTex.sample(inSamplr, float2(cubeIndex.xy));

    const half3 mix = half3((reflect * mixAlpha) + palette * (1.0-mixAlpha));

    float gray =  vert.shade.x;
    float harmonic = vert.shade.z;
    float alpha = vert.shade.y * harmonic;

    half3 shaded = (mix * (1-alpha) + gray * alpha);

    return half4(shaded.xyz,1);
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

