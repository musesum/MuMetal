// created by musesum on 2/22/19.

import Foundation
import Metal
import MetalKit
import QuartzCore
#if os(visionOS)
import CompositorServices
#endif
import MuVision
import MuExtensions

public class FlatmapNode: RenderNode {

    private var vertices: MTLBuffer? // Metal buffer for vertex data
    private var viewSize  = SIMD2<Float>(repeating: 0)
    private var clipFrame = SIMD4<Float>(repeating: 0) // clip rect

    public init(_ pipeline: Pipeline,
                _ filename: String = "render.flatmap") {

        super.init(pipeline, "flatmap", filename, .rendering)

        makeResources()
        makePipeline()
    }

   public func makeResources() {

        let viewSize = (pipeline.metalLayer.frame.size *
                        pipeline.metalLayer.contentsScale)
        self.viewSize = SIMD2<Float>(viewSize.floats())

        let clip = AspectRatio.fillClip(from: pipeline.drawSize,
                                        to: viewSize).normalize()

        clipFrame = SIMD4<Float>(clip.floats())

        print(" FlatMap::clipFrame: \(clipFrame)")

        let w2 = Float(viewSize.width / 2)
        let h2 = Float(viewSize.height / 2)

        let metVertices: [Vertex2D] = [
            // (position texCoord)
            Vertex2D( w2,-h2, 1, 1),
            Vertex2D(-w2,-h2, 0, 1),
            Vertex2D(-w2, h2, 0, 0),
            Vertex2D( w2,-h2, 1, 1),
            Vertex2D(-w2, h2, 0, 0),
            Vertex2D( w2, h2, 1, 0)]

        let size = MemoryLayout<Vertex2D>.size * metVertices.count
        
        vertices = pipeline.device.makeBuffer(bytes: metVertices,
                                              length: size,
                                              options: .storageModeShared)

    }

    func makePipeline() {

        let vertexName = "vertexFlatmap"
        let fragmentName = "fragmentFlatmap"

        guard let vertexFunc = library.makeFunction(name: vertexName) else { return err(vertexName)}
        guard let fragmentFunc = library.makeFunction(name: fragmentName) else { return err(fragmentName) }

        // descriptor pipeline state object
        let pd = MTLRenderPipelineDescriptor()
        pd.label = "Texturing Pipeline"
        pd.vertexFunction = vertexFunc
        pd.fragmentFunction = fragmentFunc
        pd.colorAttachments[0].pixelFormat = MetalRenderPixelFormat 
        pd.depthAttachmentPixelFormat = .depth32Float
        #if targetEnvironment(simulator)
        #elseif os(visionOS)
        pd.maxVertexAmplificationCount = 2
        #endif

        do {
            renderPipe = try pipeline.device.makeRenderPipelineState(descriptor: pd)
        } catch { err("\(error)") }

        func err(_ err: String) {
            print("⁉️ MetNodeFlatmap::makePipeline err: \(err)")
        }
    }

    override public func updateTextures() {

        inTex = inNode?.outTex // render to screen

        // no output texture here
    }
#if os(visionOS)

    /// Update projection and rotation
    override public func updateUniforms(_ layerDrawable: LayerRenderer.Drawable) {
    }

#else
    override public func updateUniforms() {
    }
#endif
    override open func renderNode(_ renderCmd: MTLRenderCommandEncoder) {
        guard let renderPipe else { return }

        let viewPort = MTLViewport(viewSize)
        renderCmd.setViewport(viewPort)
        renderCmd.setRenderPipelineState(renderPipe)

        // vertex
        renderCmd.setVertexBuffer(vertices, offset: 0, index: 0)
        renderCmd.setVertexBytes(&viewSize , length: Float2size, index: 1)
        renderCmd.setVertexBytes(&clipFrame, length: Float4size, index: 2)
        // fragment
        renderCmd.setFragmentTexture(inTex, index: 0)
        for buf in nameBuffer.values {
            renderCmd.setFragmentBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
        }
        // cull stencil
        renderCmd.setCullMode(.none) // creates artifacts
        renderCmd.setFrontFacing(.clockwise)
        renderCmd.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6) //metVertices.count
    }
}
extension FlatmapNode {
    public var cgImage: CGImage? { get {
        if let tex =  pipeline.metalLayer.nextDrawable()?.texture,
           let img = tex.toImage() {
            return img
        } else {
            return nil
        }
    }}
}
