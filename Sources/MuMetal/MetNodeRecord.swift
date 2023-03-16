
import AVKit

public class MetNodeRecord: MetNode {
    
    var isRecording = false
    var recordingStartTime = TimeInterval(0)
    
    var assetWriter: AVAssetWriter?
    var assetWriterInput: AVAssetWriterInput?
    var inputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    override public init(_ metItem: MetItem) {
        
        super.init(metItem)
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
    
    override func setupInOutTextures(via: String) {
        
        inTex = inNode?.outTex ?? makeNewTex(via)
        outTex = inTex
    }

    public override func execCommand(_ commandBuf: MTLCommandBuffer) {
        if isRecording, let inTex = inTex {
            writeFrame(inTex)
        }
    }
    
}