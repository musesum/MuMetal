//  MetTexCache.swift
//  created by musesum on 2/27/19.

import Foundation
import MetalKit

public let MetBaseFormat = MTLPixelFormat.bgra8Unorm

public class MetTexCache {

    static var cache = [MTLTexture]() //TextureCache

    static func recycleTextureFormat(_ pixelFormat: MTLPixelFormat, size: CGSize) -> MTLTexture? {
        for tex in cache {
            if  CGFloat(tex.width)  == size.width,
                CGFloat(tex.height) == size.height,
                tex.pixelFormat == pixelFormat {
                return tex
            }
        }
        return nil
    }

    public static func makeTexturePixelFormat(_ pixelFormat: MTLPixelFormat, size: CGSize, device: MTLDevice?) -> MTLTexture? {

        var tex = recycleTextureFormat(pixelFormat, size: size)

        if tex == nil {
            let td = MTLTextureDescriptor()
            td.textureType = .type2D
            td.pixelFormat = pixelFormat
            td.width = Int(size.width)
            td.height = Int(size.height)
            td.usage = [.shaderRead, .shaderWrite]
            tex = device?.makeTexture(descriptor: td)
        }
        return tex
    }
}
 
