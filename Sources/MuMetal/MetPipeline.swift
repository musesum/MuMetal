//  MetPipeline.swift
//  created by musesum on 3/13/23.

import Foundation
import Collections
import MetalKit
import Metal

open class MetPipeline: NSObject {

    public var metalLayer = CAMetalLayer()
    public var device: MTLDevice!
    public var library: MTLLibrary?

    public var flatmapNode: MetNodeRender?  // render 2d to screen
    public var cubemapNode: MetNodeCubemap?  // render cubemap to screen

    public var commandQueue: MTLCommandQueue!  // queue w/ command buffers
    public var nodeNamed = [String: MetNode]() //??  find node by name
    public var firstNode: MetNode?    // 1st node in rendering chain
    public var lastNode: MetNode?

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

    public func removeNode(_ node: MetNode) {
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

extension MetPipeline {

    public func resize(_ viewSize: CGSize, _ scale: CGFloat) {
        clipRect = MetAspect.fillClip(from: drawSize, to: viewSize).normalize()
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = viewSize
        metalLayer.layoutIfNeeded() //???
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

    public func computeNodes(_ commandBuf: MTLCommandBuffer,
                             _ node: MetNode?) -> MetNode? {
        var node = node

        // compute
        if node?.metType == .computing,
           let computeCmd = commandBuf.makeComputeCommandEncoder() {
            while let computeNode = node as? MetNodeCompute {
                computeNode.updateTextures()
                computeNode.computeNode(computeCmd)
                node = computeNode.outNode
            }
            computeCmd.endEncoding()
        }
        return node
    }
    public func renderNodes(_ commandBuf: MTLCommandBuffer,
                            _ drawable: CAMetalDrawable,
                            _ node: MetNode?) {
        var node = node
        if  node?.metType == .rendering,
            let renderCmd = commandBuf.makeRenderCommandEncoder(descriptor:  makeRenderPass(drawable)) {

            while let renderNode = node as? MetNodeRender {
                renderNode.updateTextures()
                renderNode.renderNode(renderCmd)
                node = renderNode.outNode
            }
            renderCmd.endEncoding()
        }
    }
    /// Called whenever the view needs to render a frame
    public func drawNodes() {

        if settingUp { return }

        _ = tripleSemaphore.wait(timeout:DispatchTime.distantFuture)
        tripleIndex = (tripleIndex + 1) % 3

        guard let commandBuf = commandQueue.makeCommandBuffer() else { return }
        commandBuf.addCompletedHandler { _ in
            self.tripleSemaphore.signal()
        }
        let node = computeNodes(commandBuf,firstNode)

        guard let drawable = metalLayer.nextDrawable() else { return }
        renderNodes(commandBuf, drawable, node)

        commandBuf.present(drawable)
        commandBuf.commit()
        commandBuf.waitUntilCompleted()
    }

}
