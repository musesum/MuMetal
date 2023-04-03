// pipe.render.metal

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

kernel void reflect
(
    texture2d<half, access::read>  inTex     [[ texture(0) ]],
    texture2d<half, access::write> outTex    [[ texture(1) ]],
    constant float2&               viewSize  [[ buffer(1)  ]],
    constant float4&               clipFrame [[ buffer(2)  ]],
    constant float2&               repeat    [[ buffer(3)  ]], // was 1
    constant float2&               mirror    [[ buffer(4)  ]], // was 2
    uint2                     gid [[thread_position_in_grid]])
{
    float2 pos = vertices[vertexID].position.xy; // distance from origin
    float2 tex = vertices[vertexID].texCoord.xy;

    VertexData out;
    out.xy = pos / (viewSize / 2.0); // (-1, -1) to (1, 1)
    out.position.z = 0.0;
    out.position.w = 1.0;
    out.texCoord = (tex + clipFrame.xy) * clipFrame.zw;

    texture2d<half>   colorTex [[ texture(0) ]],
    constant float2&  repeat   [[ buffer(1)  ]],
    constant float2&  mirror   [[ buffer(2)  ]],
    sampler           samplr   [[ sampler(0) ]])
{
    float2 mod;
    float2 rep = max(0.005, 1. - repeat);

    if (mirror.x < -0.5) {
        mod.x = fmod(out.texCoord.x, rep.x);
    } else {
        // mirror rep x
        mod.x = fmod(out.texCoord.x, rep.x * (1 + mirror.x));
        if (mod.x > rep.x) {
            mod.x = ((rep.x * (1 + mirror.x) - mod.x)
                       / fmax(0.0001, mirror.x));
        }
    }
    if (mirror.y < -0.5) {
        mod.y = fmod(out.texCoord.y, rep.y);
    } else {
        mod.y = fmod(out.texCoord.y, rep.y * (1 + mirror.y));
        if (mod.y > rep.y) {
            mod.y = ((rep.y * (1 + mirror.y) - mod.y)
                      / fmax(0.0001, mirror.y));
        }
    }
    float2 modNorm = mod / rep;
    const half4 colorSample = colorTex.sample(samplr, modNorm);
    return float4(colorSample.r, colorSample.g, colorSample.b, 1.0);
}

