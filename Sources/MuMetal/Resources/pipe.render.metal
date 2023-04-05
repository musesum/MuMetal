// pipe.render.metal

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} Vertex2D;

typedef struct {
    vector_float2 position;
    vector_float2 texCoord; // 2D texture coordinate
} MetVertex;

// MARK: - vertex
vertex Vertex2D vertexShader
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
fragment half4 fragmentShader
(
 Vertex2D         in       [[ stage_in   ]],
 texture2d<half>  colorTex [[ texture(0) ]],
 sampler          samplr   [[ sampler(0) ]])
{
    const half4 color = colorTex.sample(samplr, in.texCoord);
    return color;

}
