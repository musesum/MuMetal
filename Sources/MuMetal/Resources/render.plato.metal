// Plato

#include <metal_stdlib>
#include "SpatialTypes.h"

using namespace metal;

struct VertexOut {
    float4 position [[ position ]];
    float4 texCoord;
    float faceId;
    float harmonic;
};

struct PlatoUniforms {
    
    float range; // from 0 to 11 to animate
    float convex; // total depth of subdivisions
    float passthru;
    float shadowWhite;
    float shadowDepth;
    float invert;
    float zoom;
    float4 worldCamera;
};

// index ranged  0...1
struct PlatoVertex {
    float4 pos0  [[attribute(0)]]; // position at 0
    float4 pos1  [[attribute(1)]]; // position at 1
    float4 norm0 [[attribute(2)]]; // normal at 0
    float4 norm1 [[attribute(3)]]; // normal at 1
    float vertId;
    float faceId;   // shared by 3 vertices
    float harmonic; // depth of subdivision
    float phase;  // pad out 256 boundary
};

vertex VertexOut vertexPlato
(
 constant PlatoVertex*   in       [[ buffer(0) ]],
 constant PlatoUniforms& uniforms [[ buffer(1) ]],
 constant UniformEyes&   eyes     [[ buffer(3) ]],
 ushort                  ampId    [[ amplification_id]],
 uint32_t                vertId   [[ vertex_id ]])
{
    VertexOut vertOut;
    UniformEye eye = eyes.eye[ampId];

    float3 pos0  = in[vertId].pos0.xyz;
    float3 pos1  = in[vertId].pos1.xyz;
    float3 norm0 = in[vertId].norm0.xyz;
    float3 norm1 = in[vertId].norm1.xyz;

    float range01  = uniforms.range;// 0...1 maps pv0...pv1
    float4 pos   = float4((pos0 + (pos1-pos0) * range01), 1);
    float4 norm  = float4((norm0 + (norm1-norm0) * range01), 0);

    float4 camPos = uniforms.worldCamera;
    float4 worldNorm = normalize(norm);
    float4 eyeDirection = normalize(pos - camPos);

    vertOut.position = eye.projection * pos;
    vertOut.texCoord = reflect(eyeDirection, worldNorm);
    vertOut.faceId = in[vertId].faceId;
    vertOut.harmonic = in[vertId].harmonic;

    return vertOut;
}

// MARK: - fragment

fragment half4 fragmentPlatoCubeIndex
(
 VertexOut               out      [[ stage_in   ]],
 constant PlatoUniforms& uniforms [[ buffer(1)  ]],
 texturecube<half>       cubeTex  [[ texture(0) ]],
 texture2d  <half>       inTex    [[ texture(1) ]],
 texture2d  <half>       palTex   [[ texture(2) ]])
{
    constexpr sampler samplr(filter::linear, address::repeat);

    float palMod = fmod(out.faceId, 256) / 256.0;
    float2 palPos = float2(palMod, 0.0);
    half4 palette = palTex.sample(samplr, palPos);

    float3 texCoord = float3(out.texCoord.x,
                             out.texCoord.y,
                             -out.texCoord.z);
    half4 cubeIndex = cubeTex.sample(samplr, texCoord);

    half4 reflect = inTex.sample(samplr, float2(cubeIndex.xy));
    float passthru = max(uniforms.passthru, 0.001);

    const half3 mix = half3((reflect * passthru) + palette * (1.0 - passthru));

    const float count = 6;
    float gray     = uniforms.shadowWhite;
    float harmonic = out.harmonic;
    float inverse  = uniforms.invert * count;
    float alpha    = uniforms.shadowDepth * abs(harmonic-inverse);

    half3 shaded = (mix * (1-alpha) + gray * alpha);

    return half4(shaded.xyz,1);
}

/// texturecube has color information uploaded to it
/// vert.color is used for creating a shadow mixed with cube's color
fragment half4 fragmentPlatoCubeColor
(
 VertexOut         vertOut [[ stage_in   ]],
 texturecube<half> cubeTex [[ texture(0) ]])
{
    float3 texCoord = float3(vertOut.texCoord.x, vertOut.texCoord.y, -vertOut.texCoord.z);

    constexpr sampler samplr(filter::linear, address::repeat);
    return cubeTex.sample(samplr, texCoord);
}

/// no cubemap, untested
fragment half4 fragmentPlatoColor
(
 VertexOut        vertOut [[ stage_in   ]],
 texture2d <half> inTex   [[ texture(1) ]])
{
    constexpr sampler samplr(filter::linear, address::repeat);
    return inTex.sample(samplr, vertOut.texCoord.xy);
}

