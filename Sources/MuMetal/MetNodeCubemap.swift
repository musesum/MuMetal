//  Created by warren on 3/16/23.
//  Copyright © 2023 com.deepmuse. All rights reserved.


import UIKit
import Metal
import CoreImage
import simd

struct CubemapUniforms {
    var projectModel : matrix_float4x4
}

struct Vertex {
    var position : vector_float4
    var normal   : vector_float4
    init() {
        position = vector_float4([0,0,0,0])
        normal   = vector_float4([0,0,0,0])
    }
}

public class MetNodeCubemap: MetNode {

    var vertexBuf: MTLBuffer!
    var indexBuf: MTLBuffer!
    var uniformBuf: MTLBuffer!

    public var cubeTex: MTLTexture?
    public var cubeSamplr: MTLSamplerState!
    public var inSamplr: MTLSamplerState!
    var renderState: MTLRenderPipelineState!
    var cubeDex: CubeDex?
    let viaIndex: Bool
    let vertices: [Float]
    let indices: [UInt16]

    public init(_ pipeline: MetPipeline,
                _ viaIndex: Bool) {

        self.viaIndex = viaIndex

        let _0 = Float(-0.5) // position unit 0
        let _1 = Float( 0.5) // position unit 1

        vertices = [
            _0,_1,_1, 1,  0,-1, 0, 0, // +Y
            _1,_1,_1, 1,  0,-1, 0, 0,
            _1,_1,_0, 1,  0,-1, 0, 0,
            _0,_1,_0, 1,  0,-1, 0, 0,

            _0,_0,_0, 1,  0, 1, 0, 0, // -Y
            _1,_0,_0, 1,  0, 1, 0, 0,
            _1,_0,_1, 1,  0, 1, 0, 0,
            _0,_0,_1, 1,  0, 1, 0, 0,

            _0,_0,_1, 1,  0, 0, 1, 0,  // +Z
            _1,_0,_1, 1,  0, 0, 1, 0,
            _1,_1,_1, 1,  0, 0, 1, 0,
            _0,_1,_1, 1,  0, 0, 1, 0,

            _1,_0,_0, 1,  0, 0, 1, 0, // -Z
            _0,_0,_0, 1,  0, 0, 1, 0,
            _0,_1,_0, 1,  0, 0, 1, 0,
            _1,_1,_0, 1,  0, 0, 1, 0,

            _0,_0,_0, 1,  1, 0, 0, 0, // -X
            _0,_0,_1, 1,  1, 0, 0, 0,
            _0,_1,_1, 1,  1, 0, 0, 0,
            _0,_1,_0, 1,  1, 0, 0, 0,

            _1,_0,_1, 1, -1, 0, 0, 0,  // +X
            _1,_0,_0, 1, -1, 0, 0, 0,
            _1,_1,_0, 1, -1, 0, 0, 0,
            _1,_1,_1, 1, -1, 0, 0, 0,
        ]
        indices =  [
            0,   2,  3,   2,  0,  1,
            4,   6,  7,   6,  4,  5,
            8,  10, 11,  10,  8,  9,
            12, 14, 15,  14, 12, 13,
            16, 18, 19,  18, 16, 17,
            20, 22, 23,  22, 20, 21,
        ]

        super.init(pipeline, "cubemap", "pipe.cubemap", .render)

        buildShader()
        buildResources()
    }

    func buildShader() {

        let vertexName = "cubemapVertex"
        let fragmentName = (viaIndex
                            ? "cubemapIndex"
                            : "cubemapColor")

        let vd = MTLVertexDescriptor()
        vd.attributes[0].bufferIndex = 0
        vd.attributes[0].offset = 0
        vd.attributes[0].format = .float4

        vd.attributes[1].offset = MemoryLayout<vector_float4>.size
        vd.attributes[1].format = .float4
        vd.attributes[1].bufferIndex = 0

        vd.layouts[0].stepFunction = .perVertex
        vd.layouts[0].stride = MemoryLayout<Vertex>.stride

        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction   = library.makeFunction(name: vertexName)
        pd.fragmentFunction = library.makeFunction(name: fragmentName)
        pd.vertexDescriptor = vd
        pd.colorAttachments[0].pixelFormat = .bgra8Unorm
        pd.depthAttachmentPixelFormat = .depth32Float

        do { renderState = try pipeline.device.makeRenderPipelineState(descriptor: pd) }
        catch { print("🚫 \(#function) failed to create \(name), error \(error)") }
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

    func buildResources() {

        if viaIndex {
            cubeTex = makeIndexCube(pipeline.drawSize)
        } else {
            cubeTex = makeImageCube(["front", "front",
                                     "top",   "bottom",
                                     "front", "front"], pipeline.device)
            //cubeTexture = makeCube(["px","nx","py","ny","pz","nz"], device)
        }
        cubeSamplr = pipeline.makeSampler(normalized: true)
        inSamplr = pipeline.makeSampler(normalized: true)

        let verticesLen = 24 * 8 * MemoryLayout<Float>.size
        let indicesLen = 36 * MemoryLayout<UInt16>.size

        vertexBuf = pipeline.device.makeBuffer(bytes: vertices, length: verticesLen)
        indexBuf  = pipeline.device.makeBuffer(bytes: indices , length: indicesLen )

        uniformBuf = pipeline.device.makeBuffer(
            length: MemoryLayout<MetUniforms>.size * 2,
            options: .cpuCacheModeWriteCombined)!
    }

    func drawCube(_ renderEnc: MTLRenderCommandEncoder) {

        let indexLength = indexBuf.length
        let indexCount = indexLength / MemoryLayout<UInt16>.stride

        renderEnc.setRenderPipelineState(renderState)
        renderEnc.setDepthStencilState(pipeline.depthStencil(write: false))

        renderEnc.setVertexBuffer(vertexBuf , offset: 0, index: 0)
        renderEnc.setVertexBuffer(uniformBuf, offset: 0, index: 1)

        renderEnc.setFragmentTexture(cubeTex, index: 0)
        renderEnc.setFragmentSamplerState(cubeSamplr, index: 0)

        for buf in nameBuffer.values {
            renderEnc.setFragmentBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
        }

        renderEnc.drawIndexedPrimitives(
            type              : .triangle,
            indexCount        : indexCount,
            indexType         : .uint16,
            indexBuffer       : indexBuf,
            indexBufferOffset : 0)
    }
    func drawIndexCube(_ renderEnc: MTLRenderCommandEncoder) {
        guard let inTex else { return }

        renderEnc.setFragmentTexture(inTex, index: 1)
        renderEnc.setFragmentSamplerState(inSamplr, index: 1)

        drawCube(renderEnc)
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

        addQuad(cubeDex.left  , 0)
        addQuad(cubeDex.right , 1)
        addQuad(cubeDex.top   , 2)
        addQuad(cubeDex.bot   , 3)
        addQuad(cubeDex.front , 4)
        addQuad(cubeDex.back  , 5)

        func addQuad(_ quad: Quad, _ slice: Int) {

            texture.replace(region        : region,
                            mipmapLevel   : 0,
                            slice         : slice,
                            withBytes     : quad,
                            bytesPerRow   : bytesPerRow,
                            bytesPerImage : bytesPerImage)
        }
        return texture
    }

    override public func renderCommand(_ renderEnc: MTLRenderCommandEncoder) {
        if isOn { 
            if viaIndex {
                if inTex != nil {
                    drawIndexCube(renderEnc)
                }
            } else {
                drawCube(renderEnc)
            }
        }
    }

    override public func setupInOutTextures(via: String) {

        updateUniforms()
        if let inNode {

            switch inNode.name {
                case "camix", "camera": inTex = inNode.altTex
                default: inTex = inNode.outTex
            }
        }
    }

}


