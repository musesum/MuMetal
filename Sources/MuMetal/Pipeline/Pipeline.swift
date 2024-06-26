//  MetPipeline.swift
//  created by musesum on 3/13/23.

import Foundation
import Collections
import MetalKit
import Metal
#if os(visionOS)
import CompositorServices
#endif
import MuVision
import MuFlo

open class Pipeline: NSObject {

    public var metalLayer = CAMetalLayer()
    public var device: MTLDevice!
    public var library: MTLLibrary?

    public var flatmapNode: FlatmapNode?  // render 2d to screen
    public var cubemapNode: CubemapNode?  // render cubemap to screen

    public var commandQueue: MTLCommandQueue!  // queue w/ command buffers
    public var nodeNamed = [String: MetalNode]() //??  find node by name
    public var firstNode: MetalNode?    // 1st node in rendering chain
    public var lastNode: MetalNode?
    public var renderNode: MetalNode?

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
        metalLayer.backgroundColor = nil

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
                str += node.name + " -> "
            }
            node = node!.outNode
        }
        return str + "nil"
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

    public func resize(_ frame: CGRect, _ viewSize: CGSize, _ scale: CGFloat) {
        let clip = AspectRatio.fillClip(from: drawSize, to: viewSize)
        clipRect = clip.normalize()

        metalLayer.drawableSize = viewSize
        metalLayer.contentsScale = scale
        metalLayer.layoutIfNeeded()
        metalLayer.frame = frame
        print("clip\(clip.script) frame\(metalLayer.frame.script)")
        flatmapNode?.makeResources() //???
        cubemapNode?.makeResources() //???
    }

    public func makeRenderPass(_ metalDrawable: CAMetalDrawable) -> MTLRenderPassDescriptor {

        updateDepthTex()

        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = metalDrawable.texture
        renderPass.colorAttachments[0].loadAction = .dontCare
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        
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


    public func projection() -> simd_float4x4 {
        return MuFlo.projection(metalLayer.drawableSize)
    }

    public func kernelNodes(_ commandBuf: MTLCommandBuffer)  {
        var node = firstNode

        // compute
        if node?.metType == .computing,
           let computeCmd = commandBuf.makeComputeCommandEncoder() {
            while let nodeNow = node as? KernelNode {
                nodeNow.updateUniforms()
                nodeNow.updateTextures()
                nodeNow.kernelNode(computeCmd)
                node = nodeNow.outNode
            }
            computeCmd.endEncoding()
        }
        renderNode = node
    }

    /// Called whenever the view needs to render a frame
    public func renderFrame() {

        if RenderDepth.state == .immer { return } //???
        if settingUp { return }

        performCpuWork()

        _ = tripleSemaphore.wait(timeout:DispatchTime.distantFuture)
        tripleIndex = (tripleIndex + 1) % 3

        guard let commandBuf = commandQueue.makeCommandBuffer() else { fatalError("renderFrame::commandBuf") }
        commandBuf.addCompletedHandler { _ in
            self.tripleSemaphore.signal()
        }
        guard let drawable = metalLayer.nextDrawable() else { return }

        kernelNodes(commandBuf)
        
        renderMetal(commandBuf, drawable)
    }
    func performCpuWork() {
        // nothing right now
    }

    public func renderMetal(_ commandBuf: MTLCommandBuffer,
                            _ drawable: CAMetalDrawable) {

        //?? ARKit for non visionOS?
        //?? WorldTracking.shared.updateAnchorNow()
        
        var node = renderNode
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

        func err(_ msg: String) {  print("\(#function) err: \(msg)") }
    }

}
