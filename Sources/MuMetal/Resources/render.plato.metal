//  Created by warren on 2/28/23.
//  Copyright © 2023 com.deepmuse. All rights reserved.

#include <metal_stdlib>
using namespace metal;

struct PlatoVertex {
    float4 position [[ position ]];
    float4 texCoords;
    float faceId;
    float harmonic;
};

struct PlatoUniforms {
    float range;
    float harmonif;
    float colorCount;
    float colorMix;
    float shadowWhite;
    float shadowDepth;
    float invert;
    float zoom;
    float4   extra;
    float4   worldCamera;
    float4x4 identity;
    float4x4 inverse; // of identity
    float4x4 projectModel;
};

// index ranged  0...1
struct Vert01 {
    float4 p0 [[attribute(0)]]; // Point at 0
    float4 p1 [[attribute(1)]]; // Point at 1
    float4 n0 [[attribute(2)]]; // normal at 0
    float4 n1 [[attribute(3)]]; // normal at 1
    float4 extra [[attribute(4)]];
};

vertex PlatoVertex plato
(
 device Vert01 const*    vert01   [[ buffer(0) ]],
 constant PlatoUniforms& uniforms [[ buffer(1) ]],
 uint32_t                vid      [[ vertex_id ]])
{
    float faceId   = vert01[vid].extra.y; // shared by 3 vertices
    float harmonic = vert01[vid].extra.z;
    float range    = uniforms.range;     // 0...1 maps pv0...pv1

    float3 p0 = vert01[vid].p0.xyz;
    float3 p1 = vert01[vid].p1.xyz;
    float3 n0 = vert01[vid].n0.xyz;
    float3 n1 = vert01[vid].n1.xyz;
    float4 pos  = float4((p0 + (p1 - p0) * range),1);
    float4 norm = float4((n0 + (n1 - n0) * range),0);

    float4 camPos = uniforms.worldCamera;
    float4 worldPos = uniforms.identity * pos;
    float4 worldNorm = normalize(uniforms.inverse * norm);
    float4 eyeDirection = normalize(worldPos - camPos);

    PlatoVertex outVert;
    outVert.position = uniforms.projectModel * pos;
    outVert.texCoords = reflect(eyeDirection, worldNorm);

    outVert.faceId = faceId;
    outVert.harmonic = harmonic;
    return outVert;
}
/// texturecube has index to a texture2d
/// vert.color is used for creating a shadow mixed texture2d's color
fragment half4 platoCubeIndex
(
 PlatoVertex             vert       [[ stage_in   ]],
 constant PlatoUniforms& uniforms   [[ buffer(1) ]],
 texturecube<half>       cubeTex    [[ texture(0) ]],
 texture2d  <half>       inTex      [[ texture(1) ]],
 texture2d  <half>       palTex     [[ texture(2) ]],
 sampler                 cubeSamplr [[ sampler(0) ]],
 sampler                 inSamplr   [[ sampler(1) ]],
 sampler                 palSamplr  [[ sampler(2) ]])
{

    float palMod = fmod(vert.faceId + uniforms.colorCount, 256);
    float2 palPos = float2(palMod,0);
    half4 palette = palTex.sample(palSamplr, palPos);

    float3 cubeCoords = float3(vert.texCoords.x,
                               vert.texCoords.y,
                               -vert.texCoords.z);
    half4 cubeIndex = cubeTex.sample(cubeSamplr, cubeCoords);
    half4 reflect = inTex.sample(inSamplr, float2(cubeIndex.xy));

    const half3 mix = half3((reflect * uniforms.colorMix) +
                            palette * (1.0-uniforms.colorMix));
    const float count = 6;
    float gray     = uniforms.shadowWhite;
    float harmonic = vert.harmonic;
    float inverse  = uniforms.invert * count;
    float alpha    = uniforms.shadowDepth * abs(harmonic-inverse);

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
//    const half4 c = half4(vert.color);
//    const half4 reflect = (s*2 + c) / 2;
    return s;
}

/// no cubemap, color is contained within PlatoVertex.color
fragment half4 platoColor
(
 PlatoVertex vert [[ stage_in ]])
{
//    const half4 c = half4(vert.color);
//    const half4 color = half4(c.xyz,1);
//    return color;
    return half4(0.5, 0.5, 0.5, 0.5);
}

