//  Created by warren on 4/2/23.
//  Copyright © 2023 DeepMuse. All rights reserved.


import Metal

open class MetNodeCompute: MetNode {

    var computeState: MTLComputePipelineState? // _cellRulePipeline;
    var threadSize = MTLSize()
    var threadCount = MTLSize()

    public init(_ pipeline: MetPipeline,
                _ name: String,
                _ filename: String = "") {

        super.init(pipeline, name, filename, .compute)

        makeComputeState()
        setupThreadGroup()
    }
    func setupThreadGroup() {

        threadSize = MTLSizeMake(16, 16, 1)
        let itemW = pipeline.drawSize.width
        let itemH = pipeline.drawSize.height
        let threadW = CGFloat(threadSize.width)
        let threadH = CGFloat(threadSize.height)
        threadCount.width  = Int((itemW + threadW - 1.0) / threadW)
        threadCount.height = Int((itemH + threadH - 1.0) / threadH)
        threadCount.depth  = 1
    }

    func makeComputeState() {
        if let device = pipeline.device,
           let function,
           let state = try? device.makeComputePipelineState(function: function) {

            self.computeState = state

        } else {
            print("⁉️ makeComputeState: \(name) failed")
        }
    }

    override public func computeCommand(_ computeEnc: MTLComputeCommandEncoder) {
        // setup and execute compute textures

        if let computeState {

            if let inTex  { computeEnc.setTexture(inTex,  index: 0) }
            if let outTex { computeEnc.setTexture(outTex, index: 1) }
            if let altTex { computeEnc.setTexture(altTex, index: 2) }

            computeEnc.setSamplerState(samplr, index: 0) // need this

            // compute buffer index is in order of declaration in flo script
            for buf in nameBuffer.values {
                computeEnc.setBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
            }
            // execute the compute pipeline threads
            computeEnc.setComputePipelineState(computeState)
            computeEnc.dispatchThreadgroups(threadCount, threadsPerThreadgroup: threadSize)
        }
    }
}
