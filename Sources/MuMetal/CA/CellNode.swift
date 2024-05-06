//  created by musesum on 2/22/19.

import Foundation
import Metal
import MetalKit

public class CellNode: KernelNode {
    
    // cellular automata uses double buffering
    override public func updateTextures() {

        if !isOn && outTex != nil { return }
        inTex = inNode?.outTex
        outTex = outTex ?? makeNewTex(name)
    }

    override public func kernelNode(_ computeCmd: MTLComputeCommandEncoder) {

        if isOn {
            super.kernelNode(computeCmd)

            if let loops = nameBuffer["loops"]?.float, loops >= 1 {
                for _ in 1 ..< Int(loops) {
                    flipInOutTextures()
                    super.kernelNode(computeCmd)
                }
            }
        }
        // cellular automata uses double buffering
        func flipInOutTextures() {
            let temp = inTex
            inTex = outTex
            outTex = temp
        }
    }
}
