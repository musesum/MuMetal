// created by musesum on 1/4/24

import MetalKit
import MuVision

public class CubemapMetal: MeshMetal {

    var model: CubemapModel!

    init(_ device: MTLDevice) {

        // compare  write  cull   winding
        // .less    true  .back  .counterClockwise -- frozen, jaggy plato, flat ok
        // .less    false .back  .counterClockwise -- frozen, jaggy plato, flat ok
        // .greater true  .front .clockwise        -- frozen, jaggy plato, flat ok
        // .less    true  .front .clockwise        -- frozen, jaggy plato
        // .greater true  .none, .clockwise        -- no cubemap
        // .greater true  .none, .counterClockwise -- no cubemap
        // .greater false .none, .counterClockwise -- no cubemap
        // .less    true  .front .counterClockwise -- occlude plato
        // .less    true  .none  .counterClockwise -- occlude plato
        // .less    true  .none  .clockwise        -- occlude plato
        // .less    true  .back  .clockwise        -- occlude plato
        // .less    false .back  .clockwise        -- metal good!

        super.init(device, cull: .back, winding: .clockwise)
        self.stencil = MeshMetal.stencil(device, .less, false)

        let nameFormats: [VertexNameFormat] = [
            ("position", .float4)
        ]
        let vertexStride = MemoryLayout<VertexCube>.stride
        model = CubemapModel(device, nameFormats,vertexStride)
        mtkMesh = try! MTKMesh(mesh: model.mdlMesh, device: device)
    }
}
