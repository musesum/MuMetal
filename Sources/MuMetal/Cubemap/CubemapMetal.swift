// created by musesum on 1/4/24

import MetalKit
import MuVision

public class CubemapMetal: MeshMetal {

    var model: CubemapModel!
    
    init(_ device: MTLDevice) {

        super.init(DepthRendering(
            device,
            immer: RenderDepth(.none, .clockwise, .greater, true),
            //immer: RenderDepth(.none, .clockwise, .less, true), missing cube
            //immer: RenderDepth(.none, .clockwise, .less, false), missing cube

            //immer: RenderDepth(.none, .clockwise, .greater, true), ok?

            //immer: RenderDepth(.none, .counterClockwise, .greater, true),
            //immer: RenderDepth(.none, .counterClockwise, .greater, true), hidden
            //immer: RenderDepth(.none, .counterClockwise, .less, true), hidden

            metal: RenderDepth(.none,  .clockwise       , .less   , false)))

        let nameFormats: [VertexNameFormat] = [
            ("position", .float4),
        ]
        let vertexStride = MemoryLayout<VertexCube>.stride
        model = CubemapModel(device, nameFormats, vertexStride)
        mtkMesh = try! MTKMesh(mesh: model.mdlMesh, device: device)
    }
}
