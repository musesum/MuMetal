//  created by musesum on 3/16/23.

import UIKit
import Metal
import CoreImage
import simd
import ModelIO
import MetalKit
import MuVision

public class ModelCubemap {
    let vertices: [Float]
    let indices: [UInt16]
    let device: MTLDevice
    let mdlMesh: MDLMesh
    var vertexBuf: MTLBuffer!
    var indexBuf: MTLBuffer!

    struct VertexCube {
        var position : vector_float4 = .zero
    }

    init(_ device: MTLDevice,
         _ metalVD: MTLVertexDescriptor) {

        self.device = device

        let _0 = Float(-0.5) // position unit 0
        let _1 = Float( 0.5) // position unit 1

        vertices = [
            _0,_1,_1, 1,   _1,_1,_1, 1,  _1,_1,_0, 1,  _0,_1,_0, 1, // +Y
            _0,_0,_0, 1,   _1,_0,_0, 1,  _1,_0,_1, 1,  _0,_0,_1, 1, // -Y
            _0,_0,_1, 1,   _1,_0,_1, 1,  _1,_1,_1, 1,  _0,_1,_1, 1, // +Z
            _1,_0,_0, 1,   _0,_0,_0, 1,  _0,_1,_0, 1,  _1,_1,_0, 1, // -Z
            _0,_0,_0, 1,   _0,_0,_1, 1,  _0,_1,_1, 1,  _0,_1,_0, 1, // -X
            _1,_0,_1, 1,   _1,_0,_0, 1,  _1,_1,_0, 1,  _1,_1,_1, 1, // +X
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
        let indicesLen = indices.count * MemoryLayout<UInt16>.size
        vertexBuf = device.makeBuffer(bytes: vertices, length: verticesLen)
        indexBuf  = device.makeBuffer(bytes: indices , length: indicesLen )

        let allocator = MTKMeshBufferAllocator(device: device)
        let vertexData = Data(bytes: vertices, count: verticesLen)
        let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)

        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.stride)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)

        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: indices.count,
                                 indexType: .uint16,
                                 geometryType: .triangles,
                                 material: nil) // You can create a default MDLMaterial if needed

        mdlMesh = MDLMesh(vertexBuffers: [vertexBuffer],
                          vertexCount: vertices.count,
                          descriptor:  metalVD.modelVD,
                          submeshes: [submesh])

    }
}
public class MeshCubemap: MeshBase {

    var model: ModelCubemap!

    init(_ device: MTLDevice) {
        super.init(device: device, compare: .less, winding: .counterClockwise)
        model = ModelCubemap(device, metalVD)

        mtkMesh = try! MTKMesh(mesh: model.mdlMesh, device: device)
    }

    override public func makeMetalVD() {
        addVertexFormat(.float4, 0)
    }
}

public class MetNodeCubemap: MetNodeRender {

    struct CubemapUniforms {
        var projectModel : matrix_float4x4
    }

    private var uniformBuf: MTLBuffer!
    private var meshCubemap: MeshCubemap!
    private var cubeDex: CubeDex?
    private let viaIndex: Bool

    public var cubeTex: MTLTexture?

    public init(_ pipeline: MetPipeline,
                _ viaIndex: Bool) {

        self.meshCubemap = MeshCubemap(pipeline.device)
        self.viaIndex = viaIndex
        super.init(pipeline, "cubemap", "render.cubemap", .rendering)

        makePipeline()
        makeResources()
    }

    func makePipeline() {

        let vertexName = "vertexCubemap"
        let fragmentName = (viaIndex
                            ? "fragmentCubeIndex"
                            : "fragmentCubeColor")

        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction   = library.makeFunction(name: vertexName)
        pd.fragmentFunction = library.makeFunction(name: fragmentName)
        pd.vertexDescriptor = meshCubemap.metalVD
        pd.colorAttachments[0].pixelFormat = .bgra8Unorm
        pd.depthAttachmentPixelFormat = .depth32Float

        do {
            renderPipe = try pipeline.device.makeRenderPipelineState(descriptor: pd)
        }
        catch { print("⁉️ \(#function) failed to create \(name), error \(error)") }
    }

    func updateUniforms() {

        let orientation = Motion.shared.updateDeviceOrientation()
        let perspective = pipeline.perspective()
        let viewModel = orientation * identity
        let projectModel = perspective * viewModel
        var cubemapUniforms = CubemapUniforms(projectModel: projectModel)

        let uniformLen = MemoryLayout<CubemapUniforms>.stride
        memcpy(uniformBuf.contents(), &cubemapUniforms,  uniformLen)
    }

    func makeResources() {

        if viaIndex {
            cubeTex = makeIndexCube(pipeline.drawSize)
        } else {
            cubeTex = makeImageCube(["front", "front",
                                     "top",   "bottom",
                                     "front", "front"], pipeline.device)

            //cubeTexture = makeCube(["px","nx","py","ny","pz","nz"], device)
        }

        uniformBuf = pipeline.device.makeBuffer(
            length: MemoryLayout<CubemapUniforms>.stride,
            options: .cpuCacheModeWriteCombined)!

    }

    public func renderNode_(_ renderCmd: MTLRenderCommandEncoder) {
        guard isOn else { return }

        renderCmd.setRenderPipelineState(renderPipe)
        renderCmd.setVertexBuffer(uniformBuf, offset: 0, index: 1)
        renderCmd.setFragmentTexture(cubeTex, index: 0)
        if viaIndex, let inTex {
            renderCmd.setFragmentTexture(inTex, index: 1)
        }
        for buf in nameBuffer.values {
            renderCmd.setFragmentBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
        }
        meshCubemap.drawMesh(renderCmd) //????
    }

    override public func renderNode(_ renderCmd: MTLRenderCommandEncoder) {
        guard isOn else { return }

        renderCmd.setRenderPipelineState(renderPipe)
        renderCmd.setVertexBuffer(uniformBuf, offset: 0, index: 1)
        renderCmd.setFragmentTexture(cubeTex, index: 0)
        if viaIndex, let inTex {
            renderCmd.setFragmentTexture(inTex, index: 1)
        }
        for buf in nameBuffer.values {
            renderCmd.setFragmentBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
        }
         meshCubemap.drawMesh(renderCmd)
    }

    func makeImageCube(_ names: [String],
                       _ device: MTLDevice) -> MTLTexture {

        let image0 = UIImage(named: names[0])!
        let imageW = Int(image0.size.width)
        let cubeLength = imageW * Int(image0.scale)

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * imageW
        let bytesPerImage = bytesPerRow * cubeLength
        let region = MTLRegionMake2D(0, 0, cubeLength, cubeLength)

        let td = MTLTextureDescriptor
            .textureCubeDescriptor(pixelFormat : .rgba8Unorm,
                                   size        : cubeLength,
                                   mipmapped   : true)
        let texture = device.makeTexture(descriptor: td)!

        for slice in 0 ..< 6 {
            let image = UIImage(named: names[slice])!
            let data = image.cgImage!.pixelData()
            texture.replace(region:         region,
                            mipmapLevel:    0,
                            slice:          slice,
                            withBytes:      data!,
                            bytesPerRow:    bytesPerRow,
                            bytesPerImage:  bytesPerImage)
        }
        return texture
    }

    func makeIndexCube(_ size: CGSize) -> MTLTexture? {

        if cubeDex?.size != size {
            cubeDex = CubeDex(size)
        }
        guard let cubeDex else { return nil }

        let td = MTLTextureDescriptor
            .textureCubeDescriptor(pixelFormat : .rg16Float,
                                   size        : cubeDex.side,
                                   mipmapped   : true)
        let texture = pipeline.device.makeTexture(descriptor: td)!

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * cubeDex.side
        let bytesPerImage = bytesPerRow * cubeDex.side
        let region = MTLRegionMake2D(0, 0, cubeDex.side, cubeDex.side)

        addCubeFace(cubeDex.left  , 0)
        addCubeFace(cubeDex.right , 1)
        addCubeFace(cubeDex.top   , 2)
        addCubeFace(cubeDex.bot   , 3)
        addCubeFace(cubeDex.front , 4)
        addCubeFace(cubeDex.back  , 5)

        func addCubeFace(_ quad: Quad, _ slice: Int) {

            texture.replace(region        : region,
                            mipmapLevel   : 0,
                            slice         : slice,
                            withBytes     : quad,
                            bytesPerRow   : bytesPerRow,
                            bytesPerImage : bytesPerImage)
        }
        return texture
    }

    override public func updateTextures() {

        updateUniforms()

        if let inNode {

            switch inNode.name {
            case "camix", "camera": inTex = inNode.altTex
            default: inTex = inNode.outTex
            }
        }
    }

}


