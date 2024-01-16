// created by musesum on 1/4/24

import MetalKit
import MuVision

public class CubemapMetal: MeshMetal {

    var model: CubemapModel!
    
    init(_ device: MTLDevice) {

        super.init(DepthRendering(
            device,
            immerse : RenderDepth(.none, .counterClockwise, .greater, true),
            metal   : RenderDepth(.back, .clockwise       , .less   , false)))

        //  cull   winding          compare  write
        // .back  .counterClockwise .less    true  //-- frozen, jaggy plato, flat ok
        // .back  .counterClockwise .less    false //-- frozen, jaggy plato, flat ok
        // .front .clockwise        .greater true  //-- frozen, jaggy plato, flat ok
        // .front .clockwise        .less    true  //-- frozen, jaggy plato
        // .none  .clockwise        .greater true  //-- no cubemap
        // .none  .counterClockwise .greater true  //-- no cubemap
        // .none  .counterClockwise .greater false //-- no cubemap
        // .front .counterClockwise .less    true  //-- occlude plato
        // .none  .counterClockwise .less    true  //-- occlude plato
        // .none  .clockwise        .less    true  //-- occlude plato
        // .back  .clockwise        .less    true  //-- occlude plato
        // .back  .clockwise        .less    false //-- metal good!

        // .back  .clockwise        .less     false //-- jaggy
        // .back  .counterClockwise .less     false //-- jaggy
        // .none  .counterClockwise .less     false //-- jaggy
        // .none  .counterClockwise .less     true  //-- jaggy, flat ok
        // .front .counterClockwise .less     true  //-- jaggy, flat ok
        // .none  .counterClockwise .greater  true  //-- plato big, flat ok, cube no; blank
        // .none  .clockwise        .greater  true  //-- plato big, flat ok, cube no; blank
        // .front .clockwise        .greater  true  //--  jaggy plato big, flat ok, cube no; jaggy

        let nameFormats: [VertexNameFormat] = [
            ("position", .float4)
        ]
        let vertexStride = MemoryLayout<VertexCube>.stride
        model = CubemapModel(device, nameFormats,vertexStride)
        mtkMesh = try! MTKMesh(mesh: model.mdlMesh, device: device)
    }
}
