import MetalKit

struct Vertex2D {
    var position: vector_float2
    var texCoord: vector_float2  // 2D texture coordinate

    init (_ w: Float, _ h: Float, _ x: Float, _ y: Float)  {
        position = simd_make_float2(w, h)
        texCoord = simd_make_float2(x, y)
    }
}

