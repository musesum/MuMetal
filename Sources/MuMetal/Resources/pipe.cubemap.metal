
#include <metal_stdlib>
using namespace metal;

struct CubeVertex {
    float4 position [[ position ]];
    float4 texCoords;
    //float4 color;
};

struct Vertex {
    float4 position [[ attribute(0) ]];
    float4 normal   [[ attribute(1) ]];
};

struct CubemapUniforms {
    float4x4 projectModel;
};


vertex CubeVertex cubemapVertex
(
 device Vertex const*      vertices  [[ buffer(0) ]],
 constant CubemapUniforms  &uniforms [[ buffer(1) ]],
 uint32_t                  vid       [[ vertex_id ]])
{
    float4 position = vertices[vid].position;

    CubeVertex outVert;
    outVert.position = uniforms.projectModel * position;
    outVert.texCoords = position;
    return outVert;
}

fragment half4 cubemapIndexFragment
(
 CubeVertex           vert         [[ stage_in ]],
 texturecube<int16_t> cubeTex      [[ texture(0) ]],
 texture2d<half>      imageTex     [[ texture(1) ]],
 sampler              cubeSampler  [[ sampler(0) ]],
 sampler              imageSampler [[ sampler(1) ]])
{
    float3 cubeCoords = float3(vert.texCoords.x,
                               vert.texCoords.y,
                               -vert.texCoords.z);

    short4 index = cubeTex.sample(cubeSampler, cubeCoords);
    float2 texCoords = float2(index.xy) / cubeTex.get_width();
    return imageTex.sample(imageSampler, texCoords);
}

fragment half4 cubemapColorFragment
(
 CubeVertex          vert    [[ stage_in ]],
 texturecube<half>   cubeTex [[ texture(0) ]],
 sampler             samplr  [[ sampler(0) ]])
{
    float3 cubeCoords = float3(vert.texCoords.x,
                               vert.texCoords.y,
                               -vert.texCoords.z);
    half4 color = cubeTex.sample(samplr, cubeCoords);

    return color;
}

