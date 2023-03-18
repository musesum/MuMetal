//  Created by warren on 2/22/19.

import Foundation
import Metal
import MetalKit

public class MetNodeCompute: MetNode {
    
    // cellular automata uses double buffering
    override public func setupInOutTextures(via: String) {

        if !isOn && outTex != nil { return }
        nameBufId[""] = 0
        inTex = inNode?.outTex
        outTex = outTex ?? makeNewTex(via)
    }

    override public func execCommand(_ pipeline: MetPipeline) {

        if isOn {
            super.execCommand(pipeline)

            for _ in 1 ..< loops {
                flipInOutTextures()
                super.execCommand(pipeline)
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
