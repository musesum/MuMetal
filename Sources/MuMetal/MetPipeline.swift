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

    //??? public var mtkView = MTKView()           // MetalKit render view
    public var metalLayer = CAMetalLayer()
    public var device: MTLDevice!
    public var library: MTLLibrary?

    public var mtlCommand: MTLCommandQueue!  // queue w/ command buffers
    public var nodeNamed = [String: MetNode]() //??  find node by name
    public var firstNode: MetNode?    // 1st node in renderer chain
    public var lastNode: MetNode?
    public var flatmapNode: MetNode?  // render 2d to screen
    public var cubemapNode: MetNodeCubemap?  // render cubemap to screen

    public var drawSize = CGSize.zero  // size of draw surface
    public var viewSize = CGSize.zero  // size of render surface
    public var clipRect = CGRect.zero

    private var drawable: CAMetalDrawable?
    private var commandBuf: MTLCommandBuffer?
    private var renderEnc: MTLRenderCommandEncoder?
    private var computeEnc: MTLComputeCommandEncoder?

    private var tripleBuffer = DispatchSemaphore(value: 3)
    private var tripleIndex = 0

    private var depthTex: MTLTexture!
    public var settingUp = true        // ignore swapping in new shaders

    public override init() {
        
        super.init()

        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080) //??? UIScreen.main.bounds
        viewSize = bounds.size //??? 
        drawSize = (bounds.size.width > bounds.size.height
                    ? CGSize(width: 1920, height: 1080)
                    : CGSize(width: 1080, height: 1920))

        device = MTLCreateSystemDefaultDevice()!
        library = device.makeDefaultLibrary()

        metalLayer.device = device // mtkView.device = device
        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.contentsScale = 3 //??? UIScreen.main.scale
        metalLayer.framebufferOnly = true //???  mtkView.framebufferOnly = false
//        metalLayer.isPaused = true //??? mtkView.isPaused = true
//        metalLayer.delegate = self //???  mtkView.delegate = self
//        metalLayer.enableSetNeedsDisplay = true //??  mtkView.enableSetNeedsDisplay = true
        metalLayer.bounds = bounds // ???  mtkView.frame = bounds
        mtlCommand = device.makeCommandQueue()

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
    public func updateLastNode() {
        var node = firstNode
        while let outNode = node?.outNode {
            node = outNode
        }
        lastNode = node
    }
}

extension MetPipeline { //??? {: MTKViewDelegate {
//
//    public func mtkView(_ mtkView: MTKView, drawableSizeWillChange size: CGSize) {
//
//        if size.width == 0 { return }
//        viewSize = size // view.frame.size
//        clipRect = MetAspect.fillClip(from: drawSize, to: viewSize).normalize()
//        mtkView.autoResizeDrawable = false
//    }

    public func makeRenderPass(_ drawable: CAMetalDrawable) -> MTLRenderPassDescriptor {

        updateDepthTex()

        let rp = MTLRenderPassDescriptor()

        rp.colorAttachments[0].texture = drawable.texture
        rp.colorAttachments[0].loadAction = .dontCare
        rp.colorAttachments[0].storeAction = .store
        rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        rp.depthAttachment.texture = self.depthTex
        rp.depthAttachment.loadAction = .dontCare
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

    public func getRenderEnc() -> MTLRenderCommandEncoder? {

        if let commandBuf,
           let drawable {

            endComputeEnc()

            if let renderEnc {
                return renderEnc
            } else {
                renderEnc = commandBuf.makeRenderCommandEncoder(descriptor:  makeRenderPass(drawable))
                //?? renderEnc?.setDepthBias(0.1, slopeScale: 1.0, clamp: 0.0)
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
    public func draw() { //??? (in inView: MTKView) {

        if settingUp { return }

        _ = tripleBuffer.wait(timeout:DispatchTime.distantFuture)
        tripleIndex = (tripleIndex + 1) % 3
        commandBuf = mtlCommand?.makeCommandBuffer()
        commandBuf?.addCompletedHandler { _ in
            self.tripleBuffer.signal()
        }
        drawable = metalLayer.nextDrawable()

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
