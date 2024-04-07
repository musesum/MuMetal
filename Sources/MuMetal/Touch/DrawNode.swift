
import Foundation
import Metal
import MetalKit

public protocol TouchDrawDelegate {
    func drawTexture(_ texBuf: UnsafeMutablePointer<UInt32>, size: CGSize) -> Bool
}

public class DrawNode: ComputeNode {

    public var drawDelegate: TouchDrawDelegate?

    public init(_ pipeline: Pipeline,
                _ drawDelegate: TouchDrawDelegate) {

        super.init(pipeline, "draw", "compute.draw")
        self.drawDelegate = drawDelegate
    }

    override public func computeNode(_ computeCmd: MTLComputeCommandEncoder) {

        if let inTex,
           let outTex {

            let w = outTex.width
            let h = outTex.height
            let pixSize = MemoryLayout<UInt32>.size
            let bytesPerRow = w * pixSize
            let region = MTLRegionMake3D(0, 0, 0, outTex.width, outTex.height, 1)
            let cellBytes = UnsafeMutablePointer<UInt32>.allocate(capacity: w * h * pixSize)
            // get universe
            inTex.getBytes(cellBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            // draw in uninverse
            let filled = drawDelegate?.drawTexture(cellBytes, size: pipeline.drawSize) ?? false
            // put back universe
            inTex.replace(region: region, mipmapLevel: 0, withBytes: cellBytes, bytesPerRow: bytesPerRow)
            // fill both text textures
            if filled {
                outTex.replace(region: region, mipmapLevel: 0, withBytes: cellBytes, bytesPerRow: bytesPerRow)
            }
            free(cellBytes)
        }
        super.computeNode(computeCmd)
    }
}
