//  MetPipeline.swift
//  created by musesum on 3/13/23.

import Foundation
import Collections
import MetalKit
import Metal
#if os(visionOS)
import CompositorServices
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

    public func makeRenderPass(_ metalDrawable: CAMetalDrawable) -> MTLRenderPassDescriptor {

        updateDepthTex()

        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = metalDrawable.texture
        renderPass.colorAttachments[0].loadAction = .dontCare
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
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

    public func depthStencil(write: Bool) -> MTLDepthStencilState {
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .less
        depth.isDepthWriteEnabled = write
        let depthStencil = device.makeDepthStencilState(descriptor: depth)!
        return depthStencil
    }

    /// used by MetNodeCubemap
    public func makeSampler(normalized: Bool) -> MTLSamplerState{
        let sd = MTLSamplerDescriptor()
        sd.minFilter = .linear
        sd.magFilter = .linear

        // normalized: 0..1, otherwise 0..width, 0..height.
        sd.supportArgumentBuffers = normalized
        sd.normalizedCoordinates = normalized
        return device.makeSamplerState(descriptor: sd)!
    }

    public func computeNodes(_ commandBuf: MTLCommandBuffer) -> MetalNode? {
        var node = firstNode

        // compute
        if node?.metType == .computing,
           let computeCmd = commandBuf.makeComputeCommandEncoder() {
            while let computeNode = node as? ComputeNode {
                computeNode.updateUniforms()
                computeNode.updateTextures()
                computeNode.computeNode(computeCmd)
                node = computeNode.outNode
            }
            computeCmd.endEncoding()
        }
        return node
    }

    /// Called whenever the view needs to render a frame
    public func renderFrame() {

        if settingUp { return }

        _ = tripleSemaphore.wait(timeout:DispatchTime.distantFuture)
        tripleIndex = (tripleIndex + 1) % 3

        guard let commandBuf = commandQueue.makeCommandBuffer() else { fatalError("renderFrame::commandBuf") }
        commandBuf.addCompletedHandler { _ in
            self.tripleSemaphore.signal()
        }

        guard let drawable = metalLayer.nextDrawable() else { return }
        renderNodes(commandBuf, drawable)

        commandBuf.present(drawable)
        commandBuf.commit()
        commandBuf.waitUntilCompleted()
    }
    public func renderNodes(_ commandBuf: MTLCommandBuffer,
                            _ drawable: CAMetalDrawable) {

        // compute
        var node = computeNodes(commandBuf)

        // render
        if node?.metType == .rendering,
            let renderCmd = commandBuf.makeRenderCommandEncoder(descriptor:  makeRenderPass(drawable)) {

            while let renderNode = node as? RenderNode {
                renderNode.updateUniforms()
                renderNode.updateTextures()
                renderNode.renderNode(renderCmd)
                node = renderNode.outNode
            }
            renderCmd.endEncoding()
        }
    }

}