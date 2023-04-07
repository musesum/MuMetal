// pipe.render.metal

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
vertex Vertex2D renderVertex
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
fragment half4 renderColor
(
 Vertex2D         in     [[ stage_in   ]],
 texture2d<half>  inTex  [[ texture(0) ]],
 constant float2& repeat [[ buffer(1) ]],
 constant float2& mirror [[ buffer(2) ]],
 sampler          samplr [[ sampler(0) ]])
{

    float2 modulo;
    float2 repeati = max(0.005, 1. - repeat);

    if (mirror.x < -0.5) {
        modulo.x = fmod(in.texCoord.x, repeati.x);
    }
    // mirror repeati x
    else {
        modulo.x = fmod(in.texCoord.x, repeati.x * (1 + mirror.x));
        if (modulo.x > repeati.x) {
            modulo.x = (repeati.x * (1 + mirror.x) - modulo.x) / fmax(0.0001, mirror.x);
        }
    }
    if (mirror.y < -0.5) {
        modulo.y = fmod(in.texCoord.y, repeati.y);
    } else {
        modulo.y = fmod(in.texCoord.y, repeati.y * (1 + mirror.y));
        if (modulo.y > repeati.y) {
            modulo.y = (repeati.y * (1 + mirror.y) - modulo.y) / fmax(0.0001, mirror.y);
        }
    }
    float2 normalized = modulo / repeati; //float2(modulo.x/repeati.x, modulo.y/repeati.y);

    return inTex.sample(samplr, normalized);
}

