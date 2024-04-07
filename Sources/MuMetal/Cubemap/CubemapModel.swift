// created by musesum on 1/4/24
import Metal
import MuVision

public class CubemapModel: MeshModel<Float> {

    override public init(_ device: MTLDevice,
                         _ nameFormats: [VertexNameFormat],
                         _ vertexStride: Int) {

        super.init(device, nameFormats, vertexStride)

        let r = Float(10)
        vertices = [
            -r,+r,+r, 1,   +r,+r,+r, 1,  +r,+r,-r, 1,  -r,+r,-r, 1, // +Y
             -r,-r,-r, 1,   +r,-r,-r, 1,  +r,-r,+r, 1,  -r,-r,+r, 1, // -Y
             -r,-r,+r, 1,   +r,-r,+r, 1,  +r,+r,+r, 1,  -r,+r,+r, 1, // +Z
             +r,-r,-r, 1,   -r,-r,-r, 1,  -r,+r,-r, 1,  +r,+r,-r, 1, // -Z
             -r,-r,-r, 1,   -r,-r,+r, 1,  -r,+r,+r, 1,  -r,+r,-r, 1, // -X
             +r,-r,+r, 1,   +r,-r,-r, 1,  +r,+r,-r, 1,  +r,+r,+r, 1, // +X
        ]
        indices =  [
            0,   2,  3,   2,  0,  1,
            4,   6,  7,   6,  4,  5,
            8,  10, 11,  10,  8,  9,
            12, 14, 15,  14, 12, 13,
            16, 18, 19,  18, 16, 17,
            20, 22, 23,  22, 20, 21,
        ]

        let verticesLen = vertices.count * MemoryLayout<VertexCube>.stride
        let indicesLen = indices.count * indices.count * MemoryLayout<UInt32>.size

        vertexBuf = device.makeBuffer(bytes: vertices, length: verticesLen)
        indexBuf  = device.makeBuffer(bytes: indices , length: indicesLen )

        updateBuffers(verticesLen,indicesLen)
    }
}
