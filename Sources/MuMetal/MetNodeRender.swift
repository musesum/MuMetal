
//
//  MetaDraw.h
//  Sky
//
//  Created by warren on 2/22/19.
//  Copyright © 2019 DeepMuse All rights reserved.
//

import Foundation
import Metal
import MetalKit
import QuartzCore

public class MetNodeRender: MetNode {

    private var renderPipe: MTLRenderPipelineState?
    public var renderTexture: MTLTexture? { get {
        return  mtkView.currentDrawable?.texture ?? nil
       }
    }

    private var mtkView: MTKView
    private var vertices: MTLBuffer? // Metal buffer for vertex data
    private var vertexCount = 6 // number of vertices in our vertex buffer

    private var viewSize  = SIMD2<Float>(repeating: 0)
    private var clipFrame = SIMD4<Float>(repeating: 0) // clip rect

    public init(_ metItem: MetItem,
                _ mtkView:  MTKView) {

        self.mtkView = mtkView
        super.init(metItem)
        nameBufId["frame"] = 0
        nameBufId["repeat"] = 1
        nameBufId["mirror"] = 2
        let viewSize = mtkView.frame.size * mtkView.contentScaleFactor
        setupRenderPipeline(viewSize, metItem.size)
    }

    override func setupInOutTextures(via: String) {

        inTex = inNode?.outTex // render to screen
        // not output texture here
    }
    
    func setupRenderPipeline(_ viewSize: CGSize, _ drawSize: CGSize) {
        
        self.viewSize = SIMD2<Float>(Float(viewSize.width),
                                     Float(viewSize.height))
        
        let clip = MuAspect.fillClip(from: drawSize, to: viewSize).normalize()
        clipFrame = SIMD4<Float>( Float(clip.minX), Float(clip.minY),
                                  Float(clip.width), Float(clip.height))

        print("  MetNodeRender::fillClip: \(clip)")

        let w2 = Float(viewSize.width / 2)
        let h2 = Float(viewSize.height / 2)
        let v0 = Float(0)
        let v1 = Float(1)

        func MV(_ w: Float, _ h: Float, _ x: Float, _ y: Float) -> MetVertex {
            return MetVertex(position: simd_make_float2(w, h),
                             texCoord: simd_make_float2(x, y))
        }
        let quadVertices: [MetVertex] = [

            MV( w2, -h2, v1, v1),
            MV(-w2, -h2, v0, v1),
            MV(-w2,  h2, v0, v0),
            MV( w2, -h2, v1, v1),
            MV(-w2,  h2, v0, v0),
            MV( w2,  h2, v1, v0)]

        let quadSize = MemoryLayout<MetVertex>.size * vertexCount

        // Create our vertex buffer, and initialize it with our quadVertices array
        vertices = metItem.device.makeBuffer(bytes: quadVertices,
                                             length: quadSize,
                                             options: .storageModeShared)

        if  let defLib = metItem.device.makeDefaultLibrary(),
            let vertexFunc   = defLib.makeFunction(name: "vertexShader"),
            let fragmentFunc = defLib.makeFunction(name: "fragmentShader") {

            // descriptor pipeline state object
            let d = MTLRenderPipelineDescriptor()
            d.label = "Texturing Pipeline"
            d.vertexFunction = vertexFunc
            d.fragmentFunction = fragmentFunc
            d.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat

            do { renderPipe = try metItem.device.makeRenderPipelineState(descriptor: d) }
            catch { print("🚫 Failed to created _renderPipeline, error \(error)") }
        }
        setupSampler()
    }


    public override func execCommand(_ commandBuf: MTLCommandBuffer) {

        if  let renderPass = mtkView.currentRenderPassDescriptor,
            let renderEnc = commandBuf.makeRenderCommandEncoder(descriptor: renderPass),
            let renderPipe {

            let vx = Double(viewSize.x)
            let vy = Double(viewSize.y)
            let viewPort = MTLViewport(originX :  0, originY :  0,
                                       width   : vx, height  : vy,
                                       znear   :  0, zfar    :  1)
            renderEnc.setViewport(viewPort)
            renderEnc.setRenderPipelineState(renderPipe)

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
            renderEnc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
            renderEnc.endEncoding()

            if let currentDrawable = mtkView.currentDrawable {

                commandBuf.present(currentDrawable)
                commandBuf.commit()
                commandBuf.waitUntilCompleted()

            } else {
                print("🚫 MetaKernalRender could not get mtkView.currentDrawable")
            }
        }
    }
}
