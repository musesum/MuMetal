//  MetPipeline.swift
//  DeepMuse
//
//  Created by warren on 3/13/23.
//  Copyright © 2023 DeepMuse. All rights reserved.


import Foundation
import MetalKit

open class MetPipeline: NSObject {

    public var mtkView = MTKView()             // MetalKit render view
    private var mtlCommand: MTLCommandQueue?  // queue w/ command buffers

    public var nodeNamed = [String: MetNode]() // find node by name
    public var firstNode: MetNode?    // 1st node in renderer chain

    public var drawSize = CGSize.zero  // size of draw surface
    public var viewSize = CGSize.zero  // size of render surface
    public var clipRect = CGRect.zero

    public var settingOp = true        // ignore swapping in new shaders

    /// Called whenever view changes orientation or is resized
    static var mtkViewIsFirstTime = true


    public override init() {
        super.init()

        let bounds = UIScreen.main.bounds
        drawSize = (bounds.size.width > bounds.size.height
                    ? CGSize(width: 1920, height: 1080)
                    : CGSize(width: 1080, height: 1920))

        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        mtkView.framebufferOnly = false
        mtkView.delegate = self
        mtlCommand = mtkView.device?.makeCommandQueue()
    }

    public func setViewFrame(_ viewFrame: CGRect) -> MTKView {
        mtkView.frame = viewFrame
        mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        mtkView.delegate = self
        return mtkView
    }

    public func scriptPipeline() -> String {
        var str = ""
        var node = firstNode
        while node != nil {
            if let node {
                str += "\n" + node.metItem.name + "\n <- " + String.pointer(node.inTex) + "\n -> " + String.pointer(node.outTex)
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
        clipRect = MuAspect.fillClip(from: drawSize, to: viewSize).normalize()

        if  settingOp {
            setupPipeline()
            mtkView.autoResizeDrawable = false

        } else {
            //TODO: setup resize for all active MtlNodes
        }
    }
    /// Called whenever the view needs to render a frame
    public func draw(in inView: MTKView) {

        if nodeNamed.isEmpty { return } // nothing to draw yet

        settingOp = false // done setting up

        if let command = mtlCommand?.makeCommandBuffer(),
           let firstNode {

            command.label = "command"
            firstNode.nextCommand(command)

        } else {
            print("⁉️ err \(#function): firstNode.nextCommand(command)")
        }
    }
}
