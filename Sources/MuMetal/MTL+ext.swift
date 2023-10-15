//  created by musesum on 9/23/19.

import Foundation
import MetalKit

extension MTLTexture {

       public func mtlBytes() -> (UnsafeMutableRawPointer, Int) {

           let width = self.width
           let height = self.height
           let pixSize = MemoryLayout<UInt32>.size
           let rowBytes = self.width * pixSize
           let totalSize = width * height * pixSize
           let data = malloc(totalSize)!
           self.getBytes(data, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
           return (data, totalSize)
       }

       public func toImage() -> CGImage? {
           let pixSize = MemoryLayout<UInt32>.size
           let (data, totalSize) = mtlBytes()

           let pColorSpace = CGColorSpaceCreateDeviceRGB()

           let rawBitmapInfo = (CGImageAlphaInfo.noneSkipFirst.rawValue |
                                CGBitmapInfo.byteOrder32Little.rawValue)
           let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: rawBitmapInfo)

           let rowBytes = self.width * pixSize
           let releaseCallback: CGDataProviderReleaseDataCallback = { (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
               return
           }
           let provider = CGDataProvider(dataInfo: nil, data: data, size: totalSize, releaseData: releaseCallback)
           
           let cgImageRef = CGImage(width: self.width, height: self.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes, space: pColorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)!

           return cgImageRef
       }
}


extension MTLViewport {
    init(_ size: SIMD2<Float>) {
        self.init(originX : 0,
                  originY : 0,
                  width   : Double(size.x),
                  height  : Double(size.y),
                  znear   :0,
                  zfar    :1)
    }
}
