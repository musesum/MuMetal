// Cubemap

#include <metal_stdlib>

using namespace metal;

struct VertexOut {
    float4 position [[ position ]];
    float4 texCoord;
};

struct VertexCube {
    float4 position [[ attribute(0) ]];
};

struct CubemapUniforms {
    float4x4 projectModel;
};

// MARK: - Vertex

vertex VertexOut vertexCubemap
(
 constant VertexCube*      in        [[ buffer(0) ]],
 constant CubemapUniforms  &uniforms [[ buffer(1) ]],
 uint32_t                  vertexID  [[ vertex_id ]])
{
    VertexOut out;

    float4 position = in[vertexID].position;

    out.position = uniforms.projectModel * position;
    out.texCoord = position;

    return out;
}

// MARK: - Fragment via index texture

fragment half4 fragmentCubeIndex
(
 VertexOut          out     [[ stage_in   ]],
 texturecube<half>  cubeTex [[ texture(0) ]],
 texture2d<half>    inTex   [[ texture(1) ]],
 constant float2&   repeat  [[ buffer(1)  ]],
 constant float2&   mirror  [[ buffer(2)  ]])
{
    float3 texCoord = float3(out.texCoord.x,
                             out.texCoord.y,
                             -out.texCoord.z);

    constexpr sampler samplr(filter::linear,
                             address::repeat);

    half4 index = cubeTex.sample(samplr,texCoord);
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
    float2 modCoord = mod / reps;
    return inTex.sample(samplr, modCoord);
}

// MARK: - fragment color

fragment half4 fragmentCubeColor
(
 VertexOut          out     [[ stage_in   ]],
 texturecube<half>  cubeTex [[ texture(0) ]])
{
    constexpr sampler samplr(filter::linear,
                             address::repeat);

    float3 texCoord = float3(out.texCoord.x, out.texCoord.y, -out.texCoord.z);

    return cubeTex.sample(samplr, texCoord);
}
