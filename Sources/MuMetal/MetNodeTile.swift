//  created by musesum on 4/4/23.

import Metal

open class MetNodeTile: MetNodeCompute {

    public init(_ pipeline: MetPipeline,
                         _ name: String) {

        super.init(pipeline, name, "compute.tile")
    }

    // cellular automata uses double buffering
    override public func updateTextures() {

        //if !isOn && outTex != nil { return }
        inTex = inNode?.outTex
        outTex = outTex ?? makeNewTex(name)
    }

}
