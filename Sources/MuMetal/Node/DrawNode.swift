
import Foundation
import Metal
import MetalKit

public protocol TouchDrawDelegate {
    func setDrawBuffer(_ drawBuf: UnsafeMutablePointer<UInt32>, _ texSize: CGSize)
}

public class DrawNode: KernelNode {

    public var drawDelegate: TouchDrawDelegate?

    public init(_ pipeline: Pipeline,
                _ drawDelegate: TouchDrawDelegate) {

        super.init(pipeline, "draw", "kernel.draw")
        self.drawDelegate = drawDelegate
    }

    override public func kernelNode(_ computeCmd: MTLComputeCommandEncoder) {

        if let inTex,
            let drawDelegate {

            let pixSize = MemoryLayout<UInt32>.size
            let rowSize = inTex.width * pixSize
            let texSize = inTex.width * inTex.height * pixSize
            let drawBuf = UnsafeMutablePointer<UInt32>.allocate(capacity: texSize)
            
            let region = MTLRegionMake3D(0, 0, 0, inTex.width, inTex.height, 1)
            inTex.getBytes(drawBuf, bytesPerRow: rowSize, from: region, mipmapLevel: 0)
            drawDelegate.setDrawBuffer(drawBuf, pipeline.drawSize)

            TouchCanvas.flushTouchCanvas()
            
            inTex.replace(region: region, mipmapLevel: 0, withBytes: drawBuf, bytesPerRow: rowSize)
            free(drawBuf)
        }
        super.kernelNode(computeCmd)
    }
}
