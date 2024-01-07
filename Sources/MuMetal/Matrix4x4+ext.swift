//  created by musesum on 3/1/23.

import simd

public func perspective4x4(_ aspect: Float,
                           _ fovy  : Float,
                           _ nearZ : Float,
                           _ farZ  : Float) -> matrix_float4x4 {
    
    let yScale  = 1 / tan(fovy * 0.5)
    let xScale  = yScale / aspect
    let zRange  = farZ - nearZ
    let zScale  = -(farZ + nearZ) / zRange
    let wzScale = -farZ * nearZ / zRange
    let P = vector_float4([ xScale, 0, 0, 0  ])
    let Q = vector_float4([ 0, yScale, 0, 0  ])
    let R = vector_float4([ 0, 0, zScale, -1 ])
    let S = vector_float4([ 0, 0, wzScale, 0 ])
    
    let mat = matrix_float4x4([P, Q, R, S])
    return mat
}

public func translation(_ t: vector_float4) -> matrix_float4x4 {
    let X = vector_float4([  1,  0,  0,  0 ])
    let Y = vector_float4([  0,  1,  0,  0 ])
    let Z = vector_float4([  0,  0,  1,  0 ])
    let W = vector_float4([t.x,t.y,t.z,t.w ])
    
    let mat = matrix_float4x4([X,Y,Z,W])
    return mat
}
