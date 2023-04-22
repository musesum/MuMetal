//  MetPipeline.swift
//  DeepMuse
//
//  Created by warren on 3/13/23.
//  Copyright © 2023 DeepMuse. All rights reserved.

import Foundation
import Collections
import MetalKit
import Metal

open class MetPipeline: NSObject {

    public var mtkView = MTKView()           // MetalKit render view
    public var metalLayer = CAMetalLayer()
    public var device: MTLDevice!
    public var library: MTLLibrary?

    public var mtlCommand: MTLCommandQueue!  // queue w/ command buffers

    public var nodes = [MetNode]()
    public var nodeNamed = [String: MetNode]() //???  find node by name
    public var firstNode: MetNode?    // 1st node in renderer chain
    public var flatmapNode: MetNode?  // render 2d to screen
    public var cubemapNode: MetNodeCubemap?  // render cubemap to screen

    public var drawSize = CGSize.zero  // size of draw surface
    public var viewSize = CGSize.zero  // size of render surface
    public var clipRect = CGRect.zero

    private var drawable: CAMetalDrawable?
    private var commandBuf: MTLCommandBuffer?
    private var renderEnc: MTLRenderCommandEncoder?
    private var computeEnc: MTLComputeCommandEncoder?
    
    private var depthTex: MTLTexture!

    public var settingUp = true        // ignore swapping in new shaders

    public override init() {
        
        super.init()

        let bounds = UIScreen.main.bounds

        drawSize = (bounds.size.width > bounds.size.height
                    ? CGSize(width: 1920, height: 1080)
                    : CGSize(width: 1080, height: 1920))

        device = MTLCreateSystemDefaultDevice()!
        library = device.makeDefaultLibrary()

        mtkView.delegate = self
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        mtkView.framebufferOnly = false

        metalLayer = mtkView.layer as! CAMetalLayer
        metalLayer.device = device

        mtkView.device = device
        mtlCommand = device.makeCommandQueue()
        mtkView.frame = bounds

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
    /// create pipeline from script or snapshot
    open func setupPipeline() {
        print("\(#function) override me")
    }
}

extension MetPipeline: MTKViewDelegate {
    
    public func mtkView(_ mtkView: MTKView, drawableSizeWillChange size: CGSize) {

        if size.width == 0 { return }
        viewSize = size // view.frame.size
        clipRect = MetAspect.fillClip(from: drawSize, to: viewSize).normalize()
        mtkView.autoResizeDrawable = false
    }

    public func makeRenderPass(_ drawable: CAMetalDrawable) -> MTLRenderPassDescriptor {

        updateDepthTex()

        let rp = MTLRenderPassDescriptor()

        rp.colorAttachments[0].texture = drawable.texture
        rp.colorAttachments[0].loadAction = .clear
        rp.colorAttachments[0].storeAction = .store
        rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        rp.depthAttachment.texture = self.depthTex
        rp.depthAttachment.loadAction = .clear
        rp.depthAttachment.storeAction = .dontCare
        rp.depthAttachment.clearDepth = 1

        return rp

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
                    mipmapped: false)
                td.usage = .renderTarget
                td.storageMode = .memoryless

                depthTex = device.makeTexture(descriptor: td)
            }
        }
    }
    public func assemblePipeline() {
        firstNode = nodes.first
        if let firstNode {
            var prevNode = firstNode
            for i in 1 ..< nodes.count {
                let node = nodes[i]

                node.inNode = prevNode
                prevNode.outNode = node
                prevNode = node
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

    public func getRenderEnc() -> MTLRenderCommandEncoder? {

        if let commandBuf,
           let drawable {

            endComputeEnc()

            if let renderEnc {
                return renderEnc
            } else {
                renderEnc = commandBuf.makeRenderCommandEncoder(descriptor:  makeRenderPass(drawable))
                return renderEnc
            }
        }
        return nil
    }
    public func endRenderEnc() {
        renderEnc?.endEncoding()
        renderEnc = nil
    }

    public func getComputeEnc() -> MTLComputeCommandEncoder? {

        if let commandBuf {

            endRenderEnc()

            if let computeEnc {
                return computeEnc
            } else {
                computeEnc = commandBuf.makeComputeCommandEncoder()
                return computeEnc
            }
        }
        return nil
    }

    public func endComputeEnc() {

        computeEnc?.endEncoding()
        computeEnc = nil
    }


    /// Called whenever the view needs to render a frame
    public func draw(in inView: MTKView) {

        if settingUp { return }

        drawable = metalLayer.nextDrawable()
        commandBuf = mtlCommand?.makeCommandBuffer()

        if let firstNode,
           let drawable,
           let commandBuf {

            firstNode.nextCommand(commandBuf)

            commandBuf.present(drawable)
            commandBuf.commit()
            commandBuf.waitUntilCompleted()
        }
    }
}
