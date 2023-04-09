
#include <metal_stdlib>
using namespace metal;

struct Vertex3D {
    float4 position [[ position ]];
    float4 texCoord;
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
    out.texCoord = position;

    return out;
}
// MARK: - fragment

fragment half4 cubemapIndex
(
 Vertex3D           vin         [[ stage_in   ]],
 texturecube<half>  cubeTex     [[ texture(0) ]],
 texture2d<half>    inTex       [[ texture(1) ]],
 constant float2&   repeat      [[ buffer(1)  ]],
 constant float2&   mirror      [[ buffer(2)  ]],
 sampler            cubeSamplr  [[ sampler(0) ]],
 sampler            inSamplr    [[ sampler(1) ]])
{
    float3 cubeCoords = float3(vin.texCoord.x,
                               vin.texCoord.y,
                               -vin.texCoord.z);

    half4 index = cubeTex.sample(cubeSamplr, cubeCoords);
    float2 inCoord = float2(index.xy);

    float2 mod;
    float2 reps = max(0.005, 1. - repeat);

    if (mirror.x < -0.5) {
        mod.x = fmod(inCoord.x, reps.x);
    } else {
        // mirror repeati x
        mod.x = fmod(inCoord.x, reps.x * (1 + mirror.x));
        if (mod.x > reps.x) {
            mod.x = ((reps.x * (1 + mirror.x) - mod.x)
                     / fmax(0.0001, mirror.x));
        }
    }
    if (mirror.y < -0.5) {
        mod.y = fmod(inCoord.y, reps.y);
    } else {
        mod.y = fmod(inCoord.y, reps.y * (1 + mirror.y));
        if (mod.y > reps.y) {
            mod.y = ((reps.y * (1 + mirror.y) - mod.y)
                     / fmax(0.0001, mirror.y));
        }
    }
    float2 texCoord = mod / reps;
    return inTex.sample(inSamplr, texCoord);
}

fragment half4 cubemapColor
(
 Vertex3D           vin     [[ stage_in   ]],
 texturecube<half>  cubeTex [[ texture(0) ]],
 sampler            samplr  [[ sampler(0) ]])
{
    float3 cubeCoord = float3(vin.texCoord.x,
                               vin.texCoord.y,
                               -vin.texCoord.z);

    return cubeTex.sample(samplr, cubeCoord);
}
