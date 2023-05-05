//  Created by warren on 4/5/23.
//  Copyright © 2023 com.deepmuse. All rights reserved.


import simd

public struct MetUniforms {

    public var identity     : matrix_float4x4
    public var inverse      : matrix_float4x4
    public var projectModel : matrix_float4x4
    public var worldCamera  : vector_float4


    public init(identity     : matrix_float4x4,
                inverse      : matrix_float4x4,
                projectModel : matrix_float4x4,
                worldCamera  : vector_float4) {

        self.identity     = identity
        self.inverse      = inverse
        self.projectModel = projectModel
        self.worldCamera  = worldCamera
    }
}
