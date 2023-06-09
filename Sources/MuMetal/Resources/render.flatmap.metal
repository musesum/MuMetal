// render.flatmap.metal

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct Vertex2D {
    float4 position [[ position ]];
    float2 texCoord;
};

struct MetVertex {
    vector_float2 position;
    vector_float2 texCoord; // 2D texture coordinate
};

// MARK: - vertex
vertex Vertex2D flatmap
(
 constant MetVertex*  vertices  [[ buffer(0) ]],
 constant float2&     viewSize  [[ buffer(1) ]],
 constant float4&     clipFrame [[ buffer(2) ]],
 uint                 vertexID  [[ vertex_id ]])
{
    float2 pos = vertices[vertexID].position.xy; // distance from origin
    float2 tex = vertices[vertexID].texCoord.xy;
    
    Vertex2D out;
    out.position.xy = pos / (viewSize / 2.0); //(-1, -1) to (1, 1)
    out.position.z = 0.0;
    out.position.w = 1.0;
    out.texCoord = (tex + clipFrame.xy) * clipFrame.zw;
    
    return out;
}

// MARK: - fragment
fragment half4 flatmapColor
(
 Vertex2D         in     [[ stage_in   ]],
 texture2d<half>  inTex  [[ texture(0) ]],
 constant float2& repeat [[ buffer(1)  ]],
 constant float2& mirror [[ buffer(2)  ]],
 sampler          samplr [[ sampler(0) ]])
{

    float2 inCoord = in.texCoord;

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
    return inTex.sample(samplr, texCoord);
}

