//  Created by warren on 2/22/19.
//  Copyright © 2019 DeepMuse All rights reserved.

import Foundation
import Metal
import MetalKit

public typealias DrawTextureFunc = ((_ bytes: UnsafeMutablePointer<UInt32>,
                                     _ size: CGSize)->(Bool))

public typealias GetTextureFunc = ((_ size: Int) -> (UnsafeMutablePointer<UInt32>))

public class MetNodeColor: MetNode {

    private var getPal: GetTextureFunc?

    public init(_ pipeline: MetPipeline,
                _ getPal: @escaping GetTextureFunc) {

        super.init(pipeline, "color", "pipe.color", .compute)
        nameBufId["color"] = 0
        self.getPal = getPal
    }

    override public func setupInOutTextures(via: String) {
        
        super.setupInOutTextures(via: via)
        altTex = altTex ?? makePaletteTex() // 256 false color palette
        
        // draw into palette texture
        if let altTex,
           let getPal {
            
            let palSize = 256
            let pixSize = MemoryLayout<UInt32>.size
            let palRegion = MTLRegionMake3D(0, 0, 0, palSize, 1, 1)
            let bytesPerRow = palSize * pixSize
            let palBytes = getPal(palSize)
            altTex.replace(region: palRegion, mipmapLevel: 0, withBytes: palBytes, bytesPerRow: bytesPerRow)
        }
        func makePaletteTex() -> MTLTexture? {
            
            let paletteTex = MetTexCache
                .makeTexturePixelFormat(.bgra8Unorm,
                                        size: CGSize(width: 256, height: 1),
                                        device: pipeline.device)
            return paletteTex
        }
    }
}
