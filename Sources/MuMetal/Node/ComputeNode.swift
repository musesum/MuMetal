//  created by musesum on 4/2/23.

import Metal

open class ComputeNode: MetalNode {

    var computePipe: MTLComputePipelineState? // _cellRulePipeline;
    var threadSize = MTLSize()
    var threadCount = MTLSize()

    public init(_ pipeline: Pipeline,
                _ name: String,
                _ filename: String = "") {

        super.init(pipeline, name, filename, .computing)

        makeComputePipe()
        setupThreadGroup()
    }
    func setupThreadGroup() {

        ///??? https://developer.apple.com/documentation/metal/compute_passes/creating_threads_and_threadgroups

        threadSize = MTLSizeMake(16, 16, 1)
        let itemW = pipeline.drawSize.width
        let itemH = pipeline.drawSize.height
        let threadW = CGFloat(threadSize.width)
        let threadH = CGFloat(threadSize.height)
        threadCount.width  = Int((itemW + threadW - 1.0) / threadW)
        threadCount.height = Int((itemH + threadH - 1.0) / threadH)
        threadCount.depth  = 1
    }

    func makeComputePipe() {
        
        if let device = pipeline.device,
           let function,
           let state = try? device.makeComputePipelineState(function: function) {

            self.computePipe = state

        } else {
            print("⁉️ makeComputeState: \(name) failed")
        }
    }

    public func computeNode(_ computeCmd: MTLComputeCommandEncoder) {
        // setup and execute compute textures

        if let computePipe {

            if let inTex  { computeCmd.setTexture(inTex,  index: 0) }
            if let outTex { computeCmd.setTexture(outTex, index: 1) }
            if let altTex { computeCmd.setTexture(altTex, index: 2) }

            // compute buffer index is in order of declaration in flo script
            for buf in nameBuffer.values {
                computeCmd.setBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
            }
            // execute the compute pipeline threads
            computeCmd.setComputePipelineState(computePipe)
            computeCmd.dispatchThreadgroups(threadCount, threadsPerThreadgroup: threadSize)
        }
    }
}
