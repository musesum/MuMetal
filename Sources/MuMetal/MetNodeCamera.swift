
import Foundation
import Metal
import UIKit


public class MetNodeCamix: MetNodeCamera {
    
    public init(_ pipeline: MetPipeline) {
        super.init(pipeline, "camix", "pipe.camix")
    }
}

public class MetNodeCamera: MetNodeCompute {

    private var bypassTex: MTLTexture?  // bypass outTex when not on
    
    override public init(_ pipeline  : MetPipeline,
                _ name      : String = "camera",
                _ filename  : String = "pipe.camera") {

        super.init(pipeline, name, filename)
    
        nameBufId["mix"] = 0
        nameBufId["frame"] = 1
        setupSampler()
    }

    // get clipping frame from altTex
    func getAspectFill() -> CGRect {

        if  let altTex,
            let outTex {
            // output
            let ow = CGFloat(max(outTex.width, outTex.height))
            let oh = CGFloat(min(outTex.width, outTex.height))
            let oa = ow/oh
            // input
            let iw = CGFloat(max(altTex.width, altTex.height))
            let ih = CGFloat(min(altTex.width, altTex.height))
            let ia = iw/ih

            if oa < ia { // ipad front, back
                let x = round((iw - ih*oa)/2)
                let y = CGFloat.zero
                return CGRect(x: x, y: y, width: iw, height: ih)
            } else { // phone front, back (1.218)
                let y = round((ih - iw/oa)/2)
                let x = CGFloat.zero
                return CGRect(x: x, y: y, width: iw, height: ih)
            }
        }
        return .zero
    }

    override public func setMetalNodeOn(_ isOn: Bool,
                                        _ completion: @escaping ()->()) {
        print("Camera::setOn: \(isOn)")

        self.isOn = isOn

        if isOn {
            outTex = bypassTex ?? outTex ?? makeNewTex("setMetalNodeOn::\(name)")
        } else {
            bypassTex = outTex // push old outTex, restore later
            outTex = inTex // pass through outTex
        }
        completion()
    }
    

    override public func setupInOutTextures(via: String) {

        if isOn, MetCamera.shared.hasNewTex {
            // inTex is used by camix.metal, but ignored by camera.metal
            inTex = inNode?.outTex
            outTex = outTex
            altTex = MetCamera.shared.camTex
        } else {
            outTex = inTex
        }
    }

    override public func computeCommand(_ computeEnc: MTLComputeCommandEncoder) {

        if isOn, MetCamera.shared.hasNewTex {

            let frame = getAspectFill()
            if frame != .zero {
                updateBuffer("frame", frame)
                super.computeCommand(computeEnc)
            }
        }
    }
    
}
