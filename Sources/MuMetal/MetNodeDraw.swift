
import Foundation
import Metal
import MetalKit


public class MetNodeDraw: MetNode {

    public var drawFunc: DrawTextureFunc?

    public init(_ pipeline: MetPipeline,
                _ metItem: MetItem,
                _ drawFunc: @escaping DrawTextureFunc) {

        super.init(pipeline, metItem)
        nameBufId["draw"] = 0
        self.drawFunc = drawFunc
    }

    public override func execCommand(_ pipeline: MetPipeline) {

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
            let filled = drawFunc?(cellBytes, metItem.size) ?? false
            // put back universe
            inTex.replace(region: region, mipmapLevel: 0, withBytes: cellBytes, bytesPerRow: bytesPerRow)
            // fill both text textures
            if filled {
                outTex.replace(region: region, mipmapLevel: 0, withBytes: cellBytes, bytesPerRow: bytesPerRow)
            }
            free(cellBytes)
        }
        super.execCommand(pipeline)
    }
}
