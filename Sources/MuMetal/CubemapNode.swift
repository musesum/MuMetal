//  created by musesum on 3/16/23.

import UIKit
import Metal
import CoreImage
import simd
import ModelIO
import MetalKit
import MuVision

public struct VertexCube {
    var position : vector_float4 = .zero
}


public class CubemapModel: MeshModel<Float> {

    override public init(_ device: MTLDevice,
                         _ nameFormats: [VertexNameFormat],
                         _ vertexStride: Int) {

        super.init(device, nameFormats, vertexStride)

        let r = Float(0.5)
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
public class CubemapMetal: MeshMetal {

    var cubemapModel: CubemapModel!

    init(_ device: MTLDevice) {
    
        super.init(device: device, compare: .less, winding: .counterClockwise)
        let nameFormats: [VertexNameFormat] = [("position", .float4)]
        let vertexStride = MemoryLayout<VertexCube>.stride
        cubemapModel = CubemapModel(device, nameFormats,vertexStride)
        mtkMesh = try! MTKMesh(mesh: cubemapModel.mdlMesh, device: device)

    }
}

public class CubemapNode: RenderNode {

    struct CubemapUniforms {
        var projectModel : matrix_float4x4
    }
    private let viaIndex: Bool
    private var cubemapMetal: CubemapMetal!
    private var uniformBuf: MTLBuffer!
    private var cubemapIndex: CubemapIndex?

    public var cubeTex: MTLTexture?

    public init(_ pipeline: Pipeline,
                _ viaIndex: Bool) {

        self.cubemapMetal = CubemapMetal(pipeline.device)
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
        pd.vertexDescriptor = cubemapMetal.metalVD
        
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
        renderCmd.setDepthStencilState(pipeline.depthStencil(write: false))

        cubemapMetal.drawMesh(renderCmd)
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

            texture.replace(region        : region,
                            mipmapLevel   : 0,
                            slice         : slice,
                            withBytes     : data!,
                            bytesPerRow   : bytesPerRow,
                            bytesPerImage : bytesPerImage)
        }
        return texture
    }

    func makeIndexCube(_ size: CGSize) -> MTLTexture? {

        if cubemapIndex?.size != size {
            cubemapIndex = CubemapIndex(size)
        }
        guard let cubemapIndex else { return nil }

        let td = MTLTextureDescriptor
            .textureCubeDescriptor(pixelFormat : .rg16Float,
                                   size        : cubemapIndex.side,
                                   mipmapped   : true)
        let texture = pipeline.device.makeTexture(descriptor: td)!

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * cubemapIndex.side
        let bytesPerImage = bytesPerRow * cubemapIndex.side
        let region = MTLRegionMake2D(0, 0, cubemapIndex.side, cubemapIndex.side)

        addCubeFace(cubemapIndex.left  , 0)
        addCubeFace(cubemapIndex.right , 1)
        addCubeFace(cubemapIndex.top   , 2)
        addCubeFace(cubemapIndex.bot   , 3)
        addCubeFace(cubemapIndex.front , 4)
        addCubeFace(cubemapIndex.back  , 5)

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


