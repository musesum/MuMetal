
import Foundation
import Metal
import UIKit


public class MetNodeCamix: MetNodeCamera {

    public init(_ pipeline: MetPipeline) {
        super.init(pipeline, "camix")
    }

}


public class MetNodeCamera: MetNode {

    private var bypassTex: MTLTexture?  // bypass outTex when not on
    
    public init(_ pipeline: MetPipeline,
                _ name: String = "camera") {
        super.init(pipeline,  MetItem(name))
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
            outTex = bypassTex ?? outTex ?? makeNewTex("setMetalNodeOn::\(metItem.name)")
        } else {
            bypassTex = outTex // push old outTex, restore later
            outTex = inTex // pass through outTex
        }
        completion()
    }
    

    override public func setupInOutTextures(via: String) {

        inTex = inNode?.outTex ?? makeNewTex(via)
        outTex = isOn ? outTex ?? makeNewTex(via) : inTex
    }

    override public func execCommand(_ commandBuf: MTLCommandBuffer) {
        if isOn {
            let camSession = MetCamera.shared
            altTex = camSession.camTex

            if let _ = altTex, camSession.camState == .streaming {

                let frame = getAspectFill()
                if frame != .zero {
                    updateBuffer("frame", frame)
                }
                super.execCommand(commandBuf)
            }
        }
    }

}
