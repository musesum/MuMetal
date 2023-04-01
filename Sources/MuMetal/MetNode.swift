
import Foundation
import Metal
import MetalKit
import QuartzCore
import MuPar

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

    public var inNode: MetNode?    // input node
    public var outNode: MetNode?   // output node

    typealias MetBufId = Int
    internal var nameBufId = [String: MetBufId]()
    internal var nameBuffer = [String: MetBuffer]()

    var computeState: MTLComputePipelineState? // _cellRulePipeline;
    var threadSize = MTLSize()
    var threadCount = MTLSize()

    public var loops = 1
    public var isOn = false
    public var pipeline: MetPipeline

    public init(_ pipeline: MetPipeline,
                _ name: String,
                _ filename: String = "",
                _ type: MetType = .compute) {

        self.pipeline = pipeline
        self.name = name
        self.filename = filename
        self.type = type

        makeLibrary()
        compileKernelFunction()
        setupThreadGroup()
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
    func compileKernelFunction() {
        guard let device = pipeline.device else { return err("pipeline device == nil")}

        if let fn = (library.makeFunction(name: name) ??
                     pipeline.library?.makeFunction(name: name))
        {
            do {
                computeState = try device.makeComputePipelineState(function: fn)
            } catch {
                err("\(error)")
            }
        }
        func err(_ str: String) {
            print("⁉️ compileKernelFunction: \(name) error: \(str)")
        }
    }

    func setupThreadGroup() {

        threadSize = MTLSizeMake(16, 16, 1)
        let itemW = pipeline.drawSize.width
        let itemH = pipeline.drawSize.height
        let threadW = CGFloat(threadSize.width)
        let threadH = CGFloat(threadSize.height)
        threadCount.width  = Int((itemW + threadW - 1.0) / threadW)
        threadCount.height = Int((itemH + threadH - 1.0) / threadH)
        threadCount.depth  = 1
    }

    func setupSampler() {

        let sd = MTLSamplerDescriptor()
        sd.minFilter    = .nearest
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

    // can override to trigger behaviors, such as turning on  camera
    public func setMetalNodeOn(_ isOn: Bool,
                               _ completion: @escaping ()->()) {
        if self.isOn != isOn {
            self.isOn = isOn
            completion()
        }
    }
    open func setupInOutTextures(via: String) {

        inTex = inNode?.outTex ?? makeNewTex(via)
        outTex = outTex ?? makeNewTex(via)
    }

    open func computeCommand(_ computeEnc: MTLComputeCommandEncoder) {
        // setup and execute compute textures

        if let computeState {

            if let inTex  { computeEnc.setTexture(inTex,  index: 0) }
            if let outTex { computeEnc.setTexture(outTex, index: 1) }
            if let altTex { computeEnc.setTexture(altTex, index: 2) }

            computeEnc.setSamplerState(samplr, index: 0)

            // compute buffer index is in order of declaration in flo script
            for buf in nameBuffer.values {
                computeEnc.setBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
            }
            // execute the compute pipeline threads
            computeEnc.setComputePipelineState(computeState)
            computeEnc.dispatchThreadgroups(threadCount, threadsPerThreadgroup: threadSize)
        }
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
