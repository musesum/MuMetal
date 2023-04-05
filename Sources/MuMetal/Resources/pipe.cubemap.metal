
#include <metal_stdlib>
using namespace metal;

struct Vertex3D {
    float4 position [[ position ]];
    float4 texCoords;
};

struct Vertex {
    float4 position [[ attribute(0) ]];
    float4 normal   [[ attribute(1) ]];
};

struct CubemapUniforms {
    float4x4 projectModel;
};

// MARK: - vertex
vertex Vertex3D cubemapVertex
(
 device Vertex const*      vertices  [[ buffer(0) ]],
 constant CubemapUniforms  &uniforms [[ buffer(1) ]],
 uint32_t                  vid       [[ vertex_id ]])
{
    float4 position = vertices[vid].position;

    Vertex3D out;
    out.position = uniforms.projectModel * position;
    out.texCoords = position;
    return out;
}
// MARK: - fragment
fragment half4 cubemapIndex
(
 Vertex3D             in          [[ stage_in ]],
 texturecube<int16_t> cubeTex     [[ texture(0) ]],
 texture2d<half>      altTex      [[ texture(1) ]],
 sampler              cubeSamplr  [[ sampler(0) ]],
 sampler              altSamplr   [[ sampler(1) ]])
{
    float3 cubeCoords = float3(in.texCoords.x,
                               in.texCoords.y,
                               -in.texCoords.z);

    short4 index = cubeTex.sample(cubeSamplr, cubeCoords);
    float2 texCoords = float2(index.xy);
    return altTex.sample(altSamplr, texCoords);
}

fragment half4 cubemapColor
(
 Vertex3D          in      [[ stage_in ]],
 texturecube<half> cubeTex [[ texture(0) ]],
 sampler           samplr  [[ sampler(0) ]])
{
    float3 cubeCoords = float3(in.texCoords.x,
                               in.texCoords.y,
                               -in.texCoords.z);

    half4 color = cubeTex.sample(samplr, cubeCoords);

    return color;
}
