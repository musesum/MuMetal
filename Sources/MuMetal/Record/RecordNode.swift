
import AVKit

public class RecordNode: KernelNode {
    
    var isRecording = false
    var recordingStartTime = TimeInterval(0)
    
    var assetWriter: AVAssetWriter?
    var assetWriterInput: AVAssetWriterInput?
    var inputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    public init(_ pipeline: Pipeline,
                _ filename: String = "kernel.record") {
        
        super.init(pipeline, "record", filename)
        // placeholder nameIndex["record"] = 0
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
    
    override public func updateTextures() {
        
        inTex = inNode?.outTex ?? makeNewTex(name)
        outTex = inTex
    }

    override public func kernelNode(_ computeCmd: MTLComputeCommandEncoder) {
        if isRecording, let inTex = inTex {
            writeFrame(inTex)
        }
    }
    
}
