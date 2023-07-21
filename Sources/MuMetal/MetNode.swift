
import Foundation
import Metal
import MetalKit
import QuartzCore
import MuVisit

public enum MetType { case compute, render }

open class MetNode: Equatable {

    var id = Visitor.nextId()
    public static func == (lhs: MetNode, rhs: MetNode) -> Bool { return lhs.id == rhs.id }
    
    public var name: String
    public var type: MetType
    public var filename = "" // optional filename for runtime compile of shader file
    
    public var inTex: MTLTexture?   // input texture 0
    public var outTex: MTLTexture?  // output texture 1
    public var altTex: MTLTexture?  // optional texture 2
    
    public var samplr: MTLSamplerState?
    public var library: MTLLibrary!
    public var function: MTLFunction?

    public var inNode: MetNode?    // input node
    public var outNode: MetNode?   // output node

    typealias MetBufId = Int
    internal var nameBuffer = [String: MetBuffer]()

    public var loops = 1
    public var isOn = false
    public var pipeline: MetPipeline

    public init(_ pipeline: MetPipeline,
                _ name: String,
                _ filename: String = "",
                _ type: MetType) {

        self.pipeline = pipeline
        self.name = name
        self.filename = filename
        self.type = type

        makeLibrary()
        makeFunction()
    }

    func makeNewTex(_ via: String) -> MTLTexture? {
        if let tex = MetTexCache.makeTexturePixelFormat(.bgra8Unorm, size: pipeline.drawSize, device: pipeline.device) {
            let texPtr = String.pointer(tex)
            print("makeNewTex via: \(via) => \(texPtr)")
            return tex
        }
        return nil
    }

    public func makeLibrary() {

        if pipeline.library?.functionNames.contains(name) ?? false {
            library = pipeline.library
            return
        }
        if let data = MuMetal.read(filename, "metal") {
            do {
                print("makeLibrary: \(name)")
                library = try pipeline.device
                    .makeLibrary(source: data,
                                 options: MTLCompileOptions())
                return
            }
            catch {
                print("⁉️ err makeLibrary: \(name) \(error)")
            }
        }
        self.library = pipeline.library
    }

    func makeFunction() {
        if let fn = (library.makeFunction(name: name) ??
                     pipeline.library?.makeFunction(name: name)) {
            function = fn
        } else {
           //?? print("⁉️ MetNode::makeFunction: \(name) not found")
        }
    }

    func setupSampler() {

        let sd = MTLSamplerDescriptor()
        sd.minFilter    = .linear
        sd.magFilter    = .linear
        sd.sAddressMode = .repeat
        sd.tAddressMode = .repeat
        sd.rAddressMode = .repeat
        samplr = pipeline.device.makeSamplerState(descriptor: sd)
    }
    
    func logMetaNodes() {

        let inName = inNode?.name ?? "nil"
        var inTexNow = ""
        var outTexNow = ""
        
        if let t = inTex  { inTexNow  = "\(Unmanaged.passUnretained(t).toOpaque())" }
        if let t = outTex { outTexNow = "\(Unmanaged.passUnretained(t).toOpaque())" }

        print(String(format:"MetNode:\(name) in:\(inName) tex:\(inTexNow) outTex:\(outTexNow)"))
        outNode?.logMetaNodes()
    }

    enum MakeFunctionError: Error { case failed }
    public func makeFunction(_ name: String) throws -> MTLFunction {
        if let fn = library.makeFunction(name:name) {
            return fn
        } else {
            throw MakeFunctionError.failed
        }
    }


    // can override to trigger behaviors, such as turning on  camera
    public func setMetalNodeOn(_ isOn: Bool,
                               _ completion: @escaping ()->()) {
        //???
            self.isOn = isOn
            completion()
        
    }
    open func setupInOutTextures(via: String) {

        inTex = inNode?.outTex ?? makeNewTex(via)
        outTex = outTex ?? makeNewTex(via)
    }

    open func computeCommand(_ computeEnc: MTLComputeCommandEncoder) {
    }
    open func renderCommand(_ renderEnc: MTLRenderCommandEncoder) {
    }

    func nextCommand(_ commandBuf: MTLCommandBuffer) {

        setupInOutTextures(via: name)

        switch type {

            case .compute:
                if let computeEnc = pipeline.getComputeEnc() {
                    computeCommand(computeEnc)
                }
                if outNode?.type == .compute {
                    // continue this compute, recycle computeEnc
                } else {
                    pipeline.endComputeEnc()
                }

            case .render:
                // uses depth to hide occulded fragments
                if let renderEnc = pipeline.getRenderEnc() {
                    renderCommand(renderEnc)
                    if  outNode?.type == .render {
                        // continue this render, recycle renderEnc
                    } else {
                        pipeline.endRenderEnc()
                    }
                }
        }
        outNode?.nextCommand(commandBuf)
    }
}
