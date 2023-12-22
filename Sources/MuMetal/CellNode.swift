//  created by musesum on 2/22/19.

import Foundation
import Metal
import MetalKit

public class CellNode: ComputeNode {
    
    // cellular automata uses double buffering
    override public func updateTextures() {

        if !isOn && outTex != nil { return }
        inTex = inNode?.outTex
        outTex = outTex ?? makeNewTex(name)
    }

    override public func computeNode(_ computeCmd: MTLComputeCommandEncoder) {

        if isOn {
            super.computeNode(computeCmd)

            for _ in 1 ..< loops {
                flipInOutTextures()
                super.computeNode(computeCmd)
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
