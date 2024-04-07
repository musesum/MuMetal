//  created by musesum on 2/22/19.

import Foundation
import Metal
import MetalKit

public typealias DrawTextureFunc = ((_ bytes: UnsafeMutablePointer<UInt32>,
                                     _ size: CGSize)->(Bool))

public typealias GetTextureFunc = ((_ size: Int) -> (UnsafeMutablePointer<UInt32>))

public class ColorNode: ComputeNode {

    public var getPal: GetTextureFunc?

    public init(_ pipeline: Pipeline,
                _ getPal: @escaping GetTextureFunc) {

        super.init(pipeline, "color", "compute.color")
        self.getPal = getPal
    }

    override public func updateTextures() {
        
        super.updateTextures()
        altTex = altTex ?? makePaletteTex() // 256 false color palette
        
        // draw into palette texture
        if let altTex,
           let getPal {
            
            let palSize = 256
            let pixSize = MemoryLayout<UInt32>.size
            let palRegion = MTLRegionMake3D(0, 0, 0, palSize, 1, 1)
            let bytesPerRow = palSize * pixSize
            let palBytes = getPal(palSize)
            altTex.replace(region: palRegion,
                           mipmapLevel: 0,
                           withBytes: palBytes,
                           bytesPerRow: bytesPerRow)
        }
        func makePaletteTex() -> MTLTexture? {
            
            let paletteTex = TextureCache
                .makeTexturePixelFormat(MetalComputePixelFormat,
                                        size: CGSize(width: 256, height: 1),
                                        device: pipeline.device)
            return paletteTex
        }
    }
}
