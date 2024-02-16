//  created by musesum on 3/16/23.

import UIKit
import Metal
import CoreImage
import simd
import ModelIO
import MetalKit
import MuVision
import MuExtensions
#if os(visionOS)
import CompositorServices
#endif

public struct VertexCube {
    var position : vector_float4 = .zero
}

public class CubemapNode: RenderNode {

    private let viaIndex     : Bool
    private var metal        : CubemapMetal!
    private var cubemapIndex : CubemapIndex?
    public var cubeTex       : MTLTexture?

    public init(_ pipeline: Pipeline,
                _ viaIndex: Bool) {

        self.metal = CubemapMetal(pipeline.device)
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
        pd.vertexDescriptor = metal.metalVD
        
        pd.colorAttachments[0].pixelFormat = MetalRenderPixelFormat
        pd.depthAttachmentPixelFormat = .depth32Float
        #if targetEnvironment(simulator)
        #elseif os(visionOS)
        pd.maxVertexAmplificationCount = 2
        #endif

        do {
            renderPipe = try pipeline.device.makeRenderPipelineState(descriptor: pd)
        }
        catch { print("⁉️ \(#function) failed to create \(name), error \(error)") }
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
        metal.eyeBuf = UniformEyeBuf(pipeline.device, "Cubemap", far: true)
    }

#if os(visionOS)

    /// Update projection and rotation
    override public func updateUniforms(_ layerDrawable: LayerRenderer.Drawable) {

//        let orientation = Motion.shared.updateDeviceOrientation()
//        let perspective = pipeline.perspective()
//        let projectModel = perspective * orientation
          let cameraPos =  vector_float4([0, 0,  -4, 1]) //???? 
        let label = (RenderDepth.state == .immer ? "👁️C⃝ubemap" : "👁️Cubemap")
        metal.eyeBuf?.updateEyeUniforms(layerDrawable, cameraPos, label)
    }

#endif
    // for both metal and visionOS passthru
    override public func updateUniforms() {

        let orientation = Motion.shared.updateDeviceOrientation()
        let projection = pipeline.projection()

        MuLog.Log("👁️cubemap", interval: 4) {
            print("\t👁️c orientation ", orientation.script)
            print("\t👁️c projection  ", projection.script)
        }
        metal.eyeBuf?.updateEyeUniforms(projection, orientation)
    }

    override public func renderNode(_ renderCmd: MTLRenderCommandEncoder) {

        guard isOn else { return }

        metal.eyeBuf?.setUniformBuf(renderCmd, "Cubemap")

        renderCmd.setRenderPipelineState(renderPipe)
        renderCmd.setFragmentTexture(cubeTex, index: 0)
        if viaIndex, let inTex {
            renderCmd.setFragmentTexture(inTex, index: 1)
        }
        for buf in nameBuffer.values {
            renderCmd.setFragmentBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
        }
        metal.drawMesh(renderCmd)
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

        if let inNode {

            switch inNode.name {
            case "camix", "camera": inTex = inNode.altTex
            default: inTex = inNode.outTex
            }
        }
    }

}


