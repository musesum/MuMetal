//  Created by warren on 4/2/23.
//  Copyright © 2023 DeepMuse. All rights reserved.


import Metal

open class MetNodeCompute: MetNode {

    public init(_ pipeline: MetPipeline,
                _ name: String,
                _ filename: String = "") {

        super.init(pipeline, name, filename, .compute)
    }

    override public func computeCommand(_ computeEnc: MTLComputeCommandEncoder) {
        // setup and execute compute textures

        if let computeState {

            if let inTex  { computeEnc.setTexture(inTex,  index: 0) }
            if let outTex { computeEnc.setTexture(outTex, index: 1) }
            if let altTex { computeEnc.setTexture(altTex, index: 2) }

            computeEnc.setSamplerState(samplr, index: 0)

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
