// Plato

#include <metal_stdlib>

using namespace metal;

struct VertexPlato {
    float4 position [[ position ]];
    float4 texCoord;
    float faceId;
    float harmonic;
};

struct PlatoUniforms {
    
    float range;    // from 0 to 1 to animate
    float harmonif; // total depth of subdivisions
    float colorCount; // number of colors to map to faces
    float colorMix;
    float shadowWhite;
    float shadowDepth;
    float invert;
    float zoom;

    float4x4 projectModel;
    float4   worldCamera;
    float4x4 identity;
    float4x4 inverse; // of identity
};

// index ranged  0...1
struct PlatoVert01 {
    float4 pos0  [[attribute(0)]]; // position at 0
    float4 pos1  [[attribute(1)]]; // position at 1
    float4 norm0 [[attribute(2)]]; // normal at 0
    float4 norm1 [[attribute(3)]]; // normal at 1
    float vertId;
    float faceId;   // shared by 3 vertices
    float harmonic; // depth of subdivision
    float padding;  // pad out 256 boundary
};

vertex VertexPlato vertexPlato
(
 constant PlatoVert01*   in       [[ buffer(0) ]],
 constant PlatoUniforms& uniforms [[ buffer(1) ]],
 uint32_t                vertexId [[ vertex_id ]])
{
    VertexPlato out;

    float range  = uniforms.range;// 0...1 maps pv0...pv1
    float3 pos0  = in[vertexId].pos0.xyz;
    float3 pos1  = in[vertexId].pos1.xyz;
    float3 norm0 = in[vertexId].norm0.xyz;
    float3 norm1 = in[vertexId].norm1.xyz;
    float4 pos   = float4((pos0+(pos1-pos0)*range), 1);
    float4 norm  = float4((norm0+(norm1-norm0)*range), 0);

    float4 camPos = uniforms.worldCamera;
    float4 worldPos = uniforms.identity * pos;
    float4 worldNorm = normalize(uniforms.inverse * norm);
    float4 eyeDirection = normalize(worldPos - camPos);

    out.position = uniforms.projectModel * pos;
    out.texCoord = reflect(eyeDirection, worldNorm);
    out.faceId = in[vertexId].faceId;
    out.harmonic = in[vertexId].harmonic;

    return out;
}

// MARK: - fragment

fragment half4 fragmentPlatoCubeIndex
(
 VertexPlato             out      [[ stage_in   ]],
 constant PlatoUniforms& uniforms [[ buffer(1)  ]],
 texturecube<half>       cubeTex  [[ texture(0) ]],
 texture2d  <half>       inTex    [[ texture(1) ]],
 texture2d  <half>       palTex   [[ texture(2) ]])
{
    constexpr sampler palSamplr(coord::pixel);

    constexpr sampler samplr(filter::linear,
                             address::repeat);

    float palMod = fmod(out.faceId + uniforms.colorCount, 256);
    float2 palPos = float2(palMod, 0);
    half4 palette = palTex.sample(palSamplr, palPos);

    float3 texCoord = float3(out.texCoord.x,
                             out.texCoord.y,
                             -out.texCoord.z);
    half4 cubeIndex = cubeTex.sample(samplr, texCoord);

    half4 reflect = inTex.sample(samplr, float2(cubeIndex.xy));

    const half3 mix =
    half3((reflect * uniforms.colorMix) +
          palette * (1.0-uniforms.colorMix));

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
 VertexPlato       out     [[ stage_in   ]],
 texturecube<half> cubeTex [[ texture(0) ]])
{
    float3 texCoord = float3(out.texCoord.x, out.texCoord.y, -out.texCoord.z);

    constexpr sampler samplr(filter::linear,
                             address::repeat);

    return cubeTex.sample(samplr, texCoord);
}

/// no cubemap, untested
fragment half4 fragmentPlatoColor
(
 VertexPlato      out   [[ stage_in   ]],
 texture2d <half> inTex [[ texture(1) ]])
{

    constexpr sampler samplr(filter::linear,
                             address::repeat);

    return inTex.sample(samplr, out.texCoord.xy);
}

