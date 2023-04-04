//  Created by warren on 4/4/23.

import Metal

open class MetNodeTile: MetNodeCompute {

    public init(_ pipeline: MetPipeline,
                         _ name: String) {

        super.init(pipeline, name, "pipe.tile")
    }

    // cellular automata uses double buffering
    override public func setupInOutTextures(via: String) {

        //if !isOn && outTex != nil { return }
        inTex = inNode?.outTex
        outTex = outTex ?? makeNewTex(via)
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
