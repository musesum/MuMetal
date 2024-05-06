//  created by musesum on 2/13/19.

import Foundation
import Metal
import MetalKit
import MuFlo

// only float buffers are allowed for now

public let Float1size = MemoryLayout<Float>.size
public let Float2size = MemoryLayout<SIMD2<Float>>.size
public let Float3size = MemoryLayout<SIMD3<Float>>.size
public let Float4size = MemoryLayout<SIMD4<Float>>.size

public class MetalBuffer {

    private var name = "" // name of Metal Kernel
    public var bufIndex = 0  // index in metal buffer
    private var device: MTLDevice // metal device

    /// the next four bufs is a kludge, as using `buf: Any!` results in a shader bug
    private var buf1 = Float(0)
    private var buf2 = SIMD2<Float>(repeating: 0)
    private var buf3 = SIMD3<Float>(repeating: 0)
    private var buf4 = SIMD4<Float>(repeating: 0)
    //private var buf: Any! // this doesn't work

    public var mtlBuffer: MTLBuffer? // buffer of constants
    public var float: Float { return buf1 }

    public init(_ name: String,
                _ index: Int,
                _ any: Any,
                _ device: MTLDevice) {

        self.name = name
        self.bufIndex = index
        self.device = device
        updateBuf(any)
    }

    func updateBuf(_ floats: Array<Float>) {

        switch floats.count {
            case 1:
                buf1 = floats[0]
                mtlBuffer = device.makeBuffer(bytes: &buf1, length: Float1size)
            case 2:
                buf2 = SIMD2<Float>(floats)
                mtlBuffer = device.makeBuffer(bytes: &buf2, length: Float2size)
            case 3:
                buf3 = SIMD3<Float>(floats)
                mtlBuffer = device.makeBuffer(bytes: &buf3, length: Float3size)
            case 4:
                buf4 = SIMD4<Float>(floats)
                mtlBuffer = device.makeBuffer(bytes: &buf4, length: Float4size)
            default:
                print("⁉️ updateFloats unknown count: \(floats)")

        }
        //print(String(format:"˚\(name):%.2f", float), terminator:" ")
    }
    func updateBuf(_ doubles: [Double]) {
        var floats = [Float]()
        for double in doubles {
            floats.append(Float(double))
        }
        updateBuf(floats)
    }
    func updateBuf(_ cgFloats: [CGFloat]) {
        var floats = [Float]()
        for cgFloat in cgFloats {
            floats.append(Float(cgFloat))
        }
        updateBuf(floats)
    }

    /// add any translated to SIMD?<Float> to mtlBuffer
    func updateBuf(_ val: Any) {

        switch val {
            case let v as Float:    updateBuf([v])
            case let v as [Float]:  updateBuf(v)
            case let v as Double:   updateBuf([v])
            case let v as [Double]: updateBuf(v)
            case let v as CGPoint:  updateBuf(v.floats())
            case let v as CGSize:   updateBuf(v.floats())
            case let v as CGRect:   updateBuf(v.floats())
            case _ as FloExprs: break
            default: print("⁉️ \(#function) unknown format: \(val)")
        }
    }
}
