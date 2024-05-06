//  created by musesum on 4/4/23.

import Metal

open class TileNode: KernelNode {
    
    public init(_ pipeline: Pipeline,
                _ name: String) {
        
        super.init(pipeline, name, "kernel.tile")
    }
    
    // cellular automata uses double buffering
    override public func updateTextures() {
        
        //if !isOn && outTex != nil { return }
        inTex = inNode?.outTex
        outTex = outTex ?? makeNewTex(name)
    }
    
}
