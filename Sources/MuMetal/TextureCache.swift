//  MetTexCache.swift
//  created by musesum on 2/27/19.

import Foundation
import MetalKit

public let MetalComputePixelFormat = MTLPixelFormat.bgra8Unorm
public let MetalRenderPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

public class TextureCache {

    static var textures = [MTLTexture]()

    static func recycleTextureFormat(_ pixelFormat: MTLPixelFormat, size: CGSize) -> MTLTexture? {
        for texture in textures {
            if  CGFloat(texture.width)  == size.width,
                CGFloat(texture.height) == size.height,
                texture.pixelFormat == pixelFormat {
                return texture
            }
        }
        return nil
    }

    public static func makeTexturePixelFormat(_ pixelFormat: MTLPixelFormat, size: CGSize, device: MTLDevice?) -> MTLTexture? {

        var texture = recycleTextureFormat(pixelFormat, size: size)

        if texture == nil {
            let td = MTLTextureDescriptor()
            td.textureType = .type2D
            td.pixelFormat = pixelFormat
            td.width = Int(size.width)
            td.height = Int(size.height)
            td.usage = [.shaderRead, .shaderWrite, .renderTarget]
            texture = device?.makeTexture(descriptor: td)
        }
        return texture
    }
}
 
