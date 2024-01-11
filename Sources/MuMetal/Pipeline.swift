//  MetPipeline.swift
//  created by musesum on 3/13/23.

import Foundation
import Collections
import MetalKit
import Metal
#if os(visionOS)
import CompositorServices
import MuVision
#endif
open class Pipeline: NSObject {

    public var metalLayer = CAMetalLayer()
    public var device: MTLDevice!
    public var library: MTLLibrary?

    public var flatmapNode: RenderNode?  // render 2d to screen
    public var cubemapNode: CubemapNode?  // render cubemap to screen

    public var commandQueue: MTLCommandQueue!  // queue w/ command buffers
    public var nodeNamed = [String: MetalNode]() //??  find node by name
    public var firstNode: MetalNode?    // 1st node in rendering chain
    public var lastNode: MetalNode?

    public var drawSize = CGSize.zero  // size of draw surface
    public var viewSize = CGSize.zero  // size of render surface
    public var clipRect = CGRect.zero

    private var tripleSemaphore = DispatchSemaphore(value: 3)
    private var tripleIndex = 0

    private var depthTex: MTLTexture!
    public var settingUp = true        // ignore swapping in new shaders

    public init(_ bounds: CGRect) {

        super.init()

        device = MTLCreateSystemDefaultDevice()!
        library = device.makeDefaultLibrary()
        metalLayer.device = device
        metalLayer.pixelFormat = MetalRenderPixelFormat

        #if os(visionOS)
        drawSize = CGSize(width: 1920, height: 1080)
        metalLayer.contentsScale = 3
        #else
        let bounds = UIScreen.main.bounds
        drawSize = (bounds.size.width > bounds.size.height
                    ? CGSize(width: 1920, height: 1080)
                    : CGSize(width: 1080, height: 1920))
        metalLayer.contentsScale = UIScreen.main.scale
        viewSize = bounds.size
        #endif
        metalLayer.framebufferOnly = false
        metalLayer.contentsGravity = .resizeAspectFill
        metalLayer.frame = bounds
        metalLayer.bounds = metalLayer.frame
        commandQueue = device.makeCommandQueue()
    }

    public func scriptPipeline() -> String {
        var str = ""
        var node = firstNode
        while node != nil {
            if let node {
                str += "\n\(node.name.pad(7))(\(node.inNode?.name ?? ""))".pad(17) +
                "-> " + (node.outNode?.name ?? "nil")
            }
            node = node!.outNode
        }
        str += "\n"
        return str
    }

    public func removeNode(_ node: MetalNode) {
        node.inNode?.outNode = node.outNode
        node.outNode?.inNode = node.inNode
    }
    
    public func updateLastNode() {
        var node = firstNode
        while let outNode = node?.outNode {
            node = outNode
        }
        lastNode = node
    }
}

extension Pipeline {

    public func resize(_ viewSize: CGSize, _ scale: CGFloat) {
        clipRect = AspectRatio.fillClip(from: drawSize, to: viewSize).normalize()
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = viewSize
        metalLayer.layoutIfNeeded()
    }

    public func resize_new(_ viewSize: CGSize, _ scale: CGFloat) {
        let clip = AspectRatio.fillClip(from: drawSize, to: viewSize)
        let clipFrame = CGRect(x: clip.minX/scale, y: clip.minY/scale, width: clip.width/scale, height: clip.height/scale)
        clipRect = clip.normalize()
        metalLayer.drawableSize = viewSize
        metalLayer.bounds = clipFrame
        metalLayer.frame = clipFrame
        metalLayer.layoutIfNeeded()
    }

    public func makeRenderPass(_ metalDrawable: CAMetalDrawable) -> MTLRenderPassDescriptor {

        updateDepthTex()

        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = metalDrawable.texture
        renderPass.colorAttachments[0].loadAction = .dontCare
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0) //????
        
        renderPass.depthAttachment.texture = self.depthTex
        renderPass.depthAttachment.loadAction = .dontCare
        renderPass.depthAttachment.storeAction = .dontCare
        renderPass.depthAttachment.clearDepth = 1
        return renderPass

        func updateDepthTex()  {

            let width = Int(metalLayer.drawableSize.width)
            let height = Int(metalLayer.drawableSize.height)

            if (depthTex == nil ||
                depthTex.width != width ||
                depthTex.height != height) {

                let td = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .depth32Float,
                    width:  width,
                    height: height,
                    mipmapped: true)
                td.usage = .renderTarget
                td.storageMode = .memoryless

                depthTex = device.makeTexture(descriptor: td)
            }
        }
    }

    public func perspective() -> simd_float4x4 {

        let size = metalLayer.drawableSize
        let aspect = Float(size.width / size.height)
        let FOV = aspect > 1 ? 60.0 : 90.0
        let FOVPI = Float(FOV * .pi / 180.0) 
        let near = Float(0.1)
        let far = Float(100)

        let perspective = perspective4x4(aspect, FOVPI, near, far)
        return perspective
    }

    public func computeNodes(_ commandBuf: MTLCommandBuffer) -> MetalNode? {
        var node = firstNode

        // compute
        if node?.metType == .computing,
           let computeCmd = commandBuf.makeComputeCommandEncoder() {
            while let nodeNow = node as? ComputeNode {
                nodeNow.updateUniforms()
                nodeNow.updateTextures()
                nodeNow.computeNode(computeCmd)
                node = nodeNow.outNode
            }
            computeCmd.endEncoding()
        }
        return node
    }

    /// Called whenever the view needs to render a frame
    public func renderFrame() {

        if settingUp { return }

        performCpuWork()

        //???? _ = tripleSemaphore.wait(timeout:DispatchTime.distantFuture)
        tripleIndex = (tripleIndex + 1) % 3

        guard let commandBuf = commandQueue.makeCommandBuffer() else { fatalError("renderFrame::commandBuf") }
//        commandBuf.addCompletedHandler { _ in
//            self.tripleSemaphore.signal()
//        }
        guard let drawable = metalLayer.nextDrawable() else { return }
        renderMetal(commandBuf, drawable)
    }
    func performCpuWork() {
        // nothing right now
    }

    public func renderMetal(_ commandBuf: MTLCommandBuffer,
                            _ drawable: CAMetalDrawable) {
        // compute
        var node = computeNodes(commandBuf)

        // render
        if node?.metType == .rendering,
            let renderCmd = commandBuf.makeRenderCommandEncoder(descriptor:  makeRenderPass(drawable)) {

            while let nodeNow = node as? RenderNode {
                nodeNow.updateUniforms()
                nodeNow.updateTextures()
                nodeNow.renderNode(renderCmd)
                node = nodeNow.outNode
            }
            renderCmd.endEncoding()
        }
        commandBuf.present(drawable)
        commandBuf.commit()
        commandBuf.waitUntilCompleted()
    }

}
