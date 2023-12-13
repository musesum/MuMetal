
import Foundation
import Metal
import MetalKit
import QuartzCore
import MuFlo

public enum MetNodeType { case computing, rendering }

open class MetNodeRender: MetNode {

    public var renderPipe: MTLRenderPipelineState!
}

open class MetNode: Equatable {

    var id = Visitor.nextId()
    public static func == (lhs: MetNode, rhs: MetNode) -> Bool { return lhs.id == rhs.id }

    public var name: String
    public var metType: MetNodeType
    public var filename = "" // optional filename for runtime compile of shader file

    public var inTex: MTLTexture?   // input texture 0
    public var outTex: MTLTexture?  // output texture 1
    public var altTex: MTLTexture?  // optional texture 2

    public var library: MTLLibrary!
    public var function: MTLFunction?

    public var inNode: MetNode?    // input node
    public var outNode: MetNode?   // output node

    typealias MetBufId = Int
    internal var nameBuffer = [String: MetBuffer]()

    public var loops = 1
    public var isOn = false
    public var pipeline: MetPipeline

    public init(_ pipeline : MetPipeline,
                _ name     : String,
                _ filename : String = "",
                _ type     : MetNodeType) {

        self.pipeline = pipeline
        self.name = name
        self.filename = filename
        self.metType = type

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

    // can override to trigger behaviors, such as turning on camera
    public func setMetalNodeOn(_ isOn: Bool,
                               _ completion: @escaping ()->()) {
        self.isOn = isOn
        completion()
    }
    open func updateTextures() {

        inTex = inNode?.outTex ?? makeNewTex(name)
        outTex = outTex ?? makeNewTex(name)
    }

//    open func computeNode(_ computeCmd: MTLComputeCommandEncoder) {
//    }
    open func renderNode(_ renderCmd: MTLRenderCommandEncoder) {
    }

}
