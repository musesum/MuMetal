// Created by warren on 2/22/19.

import Foundation
import Metal
import MetalKit
import QuartzCore

public class MetNodeRender: MetNode {

    private var renderState: MTLRenderPipelineState?

    public var cgImage: CGImage? { get {
        if let tex =  pipeline.mtkView.currentDrawable?.texture,
           let img = tex.toImage() {
            return img
        } else {
            return nil
        }
    }}
    private var vertices: MTLBuffer? // Metal buffer for vertex data
    private var viewSize  = SIMD2<Float>(repeating: 0)
    private var clipFrame = SIMD4<Float>(repeating: 0) // clip rect

    public init(_ pipeline: MetPipeline,
                _ filename: String = "pipe.render") {

        super.init(pipeline, "render", filename, .render)

        buildResources()
        buildShader()
    }

    func buildResources() {

        let viewSize = (pipeline.mtkView.frame.size *
                        pipeline.mtkView.contentScaleFactor)
        self.viewSize = SIMD2<Float>(viewSize.floats())
        let clip = MetAspect.fillClip(from: pipeline.drawSize,
                                      to: viewSize).normalize()
        clipFrame = SIMD4<Float>(clip.floats())

        //print(" MetNodeRender::clipFrame: \(clipFrame)")

        let w2 = Float(viewSize.width / 2)
        let h2 = Float(viewSize.height / 2)

        let metVertices: [MetVertex] = [
            // (position texCoord)
            MetVertex( w2,-h2, 1, 1),
            MetVertex(-w2,-h2, 0, 1),
            MetVertex(-w2, h2, 0, 0),
            MetVertex( w2,-h2, 1, 1),
            MetVertex(-w2, h2, 0, 0),
            MetVertex( w2, h2, 1, 0)]

        let quadSize = MemoryLayout<MetVertex>.size * metVertices.count

        // Create our vertex buffer, and initialize it with our quadVertices array
        vertices = pipeline.device.makeBuffer(bytes: metVertices,
                                              length: quadSize,
                                              options: .storageModeShared)
    }

    func buildShader() {
        let vertexName = "renderVertex"
        let fragmentName = "renderColor"

        guard let vertexFunc = library.makeFunction(name: vertexName) else { return err(vertexName)}
        guard let fragmentFunc = library.makeFunction(name: fragmentName) else { return err(fragmentName) }

        // descriptor pipeline state object
        let pd = MTLRenderPipelineDescriptor()
        pd.label = "Texturing Pipeline"
        pd.vertexFunction = vertexFunc
        pd.fragmentFunction = fragmentFunc
        pd.colorAttachments[0].pixelFormat = pipeline.mtkView.colorPixelFormat
        pd.depthAttachmentPixelFormat = .depth32Float

        do { renderState = try pipeline.device.makeRenderPipelineState(descriptor: pd) }
        catch { err("\(error)") }

        setupSampler()

        func err(_ err: String) {
            print("🚫 MetNodeRender::buildShader err: \(err)")
        }
    }

    override public func setupInOutTextures(via: String) {

        inTex = inNode?.outTex // render to screen
                               // no output texture here
    }

    override open func renderCommand(_ renderEnc: MTLRenderCommandEncoder) {
        guard let renderState else { return }

        let viewPort = MTLViewport(viewSize)
        renderEnc.setViewport(viewPort)
        renderEnc.setRenderPipelineState(renderState)

        // vertex
        renderEnc.setVertexBuffer(vertices, offset: 0, index: 0)
        renderEnc.setVertexBytes(&viewSize , length: Float2Len, index: 1)
        renderEnc.setVertexBytes(&clipFrame, length: Float4Len, index: 2)

        // fragment
        renderEnc.setFragmentTexture(inTex, index: 0)
        renderEnc.setFragmentSamplerState(samplr, index: 0)

        for buf in nameBuffer.values {
            renderEnc.setFragmentBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
        }
        renderEnc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6) //metVertices.count
    }
}
