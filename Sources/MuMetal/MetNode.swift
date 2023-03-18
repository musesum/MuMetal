
import Foundation
import Metal
import MetalKit
import QuartzCore
import MuPar

open class MetNode: Equatable {

    var id = Visitor.nextId()
    public static func == (lhs: MetNode, rhs: MetNode) -> Bool { return lhs.id == rhs.id }
    
    public var metItem: MetItem
    public var filename = "" // optional filename for runtime compile of shader file
    public var inTex: MTLTexture?   // input texture 0
    public var outTex: MTLTexture?  // output texture 1
    public var altTex: MTLTexture?  // optional texture 2
    public var samplr: MTLSamplerState?

    public var inNode: MetNode?    // optional input kernel
    public var outNode: MetNode?   // optional output kernel

    typealias BufId = Int
    internal var nameBufId = [String: BufId]()
    internal var nameBuffer = [String: MetBuffer]()

    var computePipeline: MTLComputePipelineState? // _cellRulePipeline;
    var threadSize = MTLSize()
    var threadCount = MTLSize()

    var depthTexture: MTLTexture!

    public var loops = 1
    public var isOn = false

    // can override to trigger behaviors, such as turning on  camera
    public func setMetalNodeOn(_ isOn: Bool,
                        _ completion: @escaping ()->()) {
        if self.isOn != isOn {
            self.isOn = isOn
            completion()
        }
    }

    public init(_ metItem: MetItem) {
        self.metItem = metItem
        compileKernelFunction()
        //??? setupInOutTextures(via: metItem.name)
        setupThreadGroup()
    }

    func makeNewTex(_ via: String) -> MTLTexture? {
        if let tex = MetTexCache.makeTexturePixelFormat(.bgra8Unorm, size: metItem.size, device: metItem.device) {
            let texPtr = String.pointer(tex)
            print("makeNewTex via: \(via) => \(texPtr)")
            return tex
        }
        return nil
    }

    func compileKernelFunction() {
        if  let defaultLib = metItem.device.makeDefaultLibrary(), //?? 
            let mtlFunction = defaultLib.makeFunction(name: metItem.name) {

            do { computePipeline = try metItem.device.makeComputePipelineState(function: mtlFunction)  }
            catch { print("Failed to create _pipeline for \(metItem.name), error \(error)") }
        }
    }

    func setupThreadGroup() {

        threadSize = MTLSizeMake(16, 16, 1)
        let itemW = metItem.size.width
        let itemH = metItem.size.height
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
        samplr = metItem.device.makeSamplerState(descriptor: sd)
    }
    
    func printMetaNodes() {

        let inName = inNode?.metItem.name ?? "nil"
        var inTexNow = ""
        var outTexNow = ""
        
        if let t = inTex  { inTexNow  = "\(Unmanaged.passUnretained(t).toOpaque())" }
        if let t = outTex { outTexNow = "\(Unmanaged.passUnretained(t).toOpaque())" }

        print(String(format:"MetaKernal:\(metItem.name) in:\(inName) tex:\(inTexNow) outTex:\(outTexNow)"))
        outNode?.printMetaNodes()
    }

    open func setupInOutTextures(via: String) {

        inTex = inNode?.outTex ?? makeNewTex(via)
        outTex = outTex ?? makeNewTex(via)
    }

    open func execCommand(_ commandBuf: MTLCommandBuffer) {
        // setup and execute compute textures

        if let cc = commandBuf.makeComputeCommandEncoder(),
           let computePipeline {

            if let inTex  { cc.setTexture(inTex,  index: 0) }
            if let outTex { cc.setTexture(outTex, index: 1) }
            if let altTex { cc.setTexture(altTex, index: 2) }

            cc.setSamplerState(samplr, index: 0)

            // compute buffer index is in order of declaration in flo script
            for buf in nameBuffer.values {
                cc.setBuffer(buf.mtlBuffer, offset: 0, index: buf.bufIndex)
            }
            // execute the compute pipeline threads
            cc.setComputePipelineState(computePipeline)
            cc.dispatchThreadgroups(threadCount, threadsPerThreadgroup: threadSize)
            cc.endEncoding()
        }
    }



    public func updateDepthBuffer(_ size: CGSize)  {
        
        let width = Int(size.width)
        let height = Int(size.height)

        if (depthTexture == nil ||
            depthTexture.width != width ||
            depthTexture.height != height) {

            buildDepthBuffer()
        }
        func buildDepthBuffer() {

            let depthTexDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .depth32Float,
                width:  Int(size.width),
                height: Int(size.height),
                mipmapped: false)

            depthTexDesc.usage = .renderTarget
            depthTexDesc.storageMode = .private
            self.depthTexture = metItem.device.makeTexture(descriptor: depthTexDesc)
        }
    }
    public func  makeDepthStencil() -> MTLDepthStencilState {
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .less
        depth.isDepthWriteEnabled = false
        return metItem.device.makeDepthStencilState(descriptor: depth)!
    }
    public func renderPass(_ drawable: CAMetalDrawable) -> MTLRenderPassDescriptor {

        let rp = MTLRenderPassDescriptor()

        rp.colorAttachments[0].texture = drawable.texture
        rp.colorAttachments[0].loadAction = .clear
        rp.colorAttachments[0].storeAction = .store
        rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        rp.depthAttachment.texture = self.depthTexture
        rp.depthAttachment.loadAction = .clear
        rp.depthAttachment.storeAction = .dontCare
        rp.depthAttachment.clearDepth = 1

        return rp
    }
    func nextCommand(_ commandBuf: MTLCommandBuffer) {
        print(metItem.name, terminator: "🟢 ")
        setupInOutTextures(via: metItem.name)
        execCommand(commandBuf)
        outNode?.nextCommand(commandBuf)
    }
}
