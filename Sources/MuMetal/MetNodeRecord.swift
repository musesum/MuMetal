
import AVKit

public class MetNodeRecord: MetNode {
    
    var isRecording = false
    var recordingStartTime = TimeInterval(0)
    
    var assetWriter: AVAssetWriter?
    var assetWriterInput: AVAssetWriterInput?
    var inputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    override public init(_ pipeline: MetPipeline,
                         _ metItem: MetItem) {
        
        super.init(pipeline, metItem)
        // placeholder nameIndex["record"] = 0
        setupSampler()
    }
    var docURL: URL?
    
    override public func setMetalNodeOn(_ isOn: Bool,
                                        _ completion: @escaping ()->()) {
        self.isOn = isOn
        if isOn {
            startRecording() {
                print("-> startRecording")
                completion()
            }
        } else {
            endRecording {
                completion()
                print("-> endRecording")
            }
        }
    }
    
    override public func setupInOutTextures(via: String) {
        
        inTex = inNode?.outTex ?? makeNewTex(via)
        outTex = inTex
    }

    override public func execCommand(_ pipeline: MetPipeline) {
        if isRecording, let inTex = inTex {
            writeFrame(inTex)
        }
    }
    
}
