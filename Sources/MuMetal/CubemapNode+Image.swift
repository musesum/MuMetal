//  created by musesum on 4/5/23.


import CoreImage
extension CubemapNode {

    func makeImageCube(_ ciImage: CIImage) -> MTLTexture? {

        let w = ciImage.extent.width
        let h = ciImage.extent.height
        let s = min(w,h)
        let rect = CGRect(x: (w-s)/2, y: (h-s)/2, width: s, height: s)

        let cii = ciImage.cropped(to: rect)
        guard let data = cii.pixelData(rect) else { return nil }

        let cubeLength = Int(s)

        let td = MTLTextureDescriptor
            .textureCubeDescriptor(pixelFormat : .rgba8Unorm,
                                   size        : cubeLength,
                                   mipmapped   : true)
        let texture = pipeline.device.makeTexture(descriptor: td)!

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * cubeLength
        let bytesPerImage = bytesPerRow * cubeLength
        let region = MTLRegionMake2D(0, 0, cubeLength, cubeLength)

        for slice in 0 ..< 6 {
            texture.replace(region        : region,
                            mipmapLevel   : 0,
                            slice         : slice,
                            withBytes     : data,
                            bytesPerRow   : bytesPerRow,
                            bytesPerImage : bytesPerImage)
        }
        return texture
    }

    func makeSquareImageTex(_ tex: MTLTexture) -> MTLTexture? {

        let w = tex.width
        let h = tex.height
        let s = min(w,h)
        let x = (w-s)/2
        let y = (h-s)/2

        // Allocate memory for the cropped texture data
        let croppedData = UnsafeMutableRawPointer.allocate(byteCount: s * s * 4, alignment: 1)

        // Get the bytes of the original texture
        let bytesPerRow = s * 4
        let bytesPerImage = bytesPerRow * s
        var region = MTLRegionMake2D(x, y, s, s)
        tex.getBytes(croppedData, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)

        // Create a new texture descriptor for the cropped texture
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: tex.pixelFormat, width: s, height: s, mipmapped: false)
        td.usage = .shaderRead
        td.storageMode = .shared

        // Create the cropped texture from the cropped data
        let squareTex = pipeline.device.makeTexture(descriptor: td)
        region = MTLRegionMake2D(0, 0, s, s)
        squareTex?.replace(region: region, mipmapLevel: 0, withBytes: croppedData, bytesPerRow: bytesPerRow)

        // Free the allocated memory
        croppedData.deallocate()
        return squareTex

    }

    public func updateCubemap(_ ciImage: CIImage?) {
        guard let ciImage else { return }
        //cubeTex = makeImageCube(ciImage)
        //cubeTex = makeIndexCube(ciImage.extent.size)
        altTex = makeSquareImageTex(ciImage)
    }

    /// create a square texture by cropping immage
    func makeSquareImageTex(_ ciImage: CIImage) -> MTLTexture? {

        let w = ciImage.extent.width
        let h = ciImage.extent.height
        let s = min(w,h)
        let rect = CGRect(x: (w-s)/2, y: (h-s)/2, width: s, height: s)

        let img = ciImage.cropped(to: rect)
        guard let data = img.pixelData(rect) else { return nil }

        let cubeLength = Int(s)

        let td = MTLTextureDescriptor
            .texture2DDescriptor(pixelFormat : .rgba8Unorm,
                                 width       : cubeLength,
                                 height      : cubeLength,
                                 mipmapped   : false)

        let tex = pipeline.device.makeTexture(descriptor: td)!

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * cubeLength
        let region = MTLRegionMake2D(0, 0, cubeLength, cubeLength)

        tex.replace(region      : region,
                    mipmapLevel : 0,
                    withBytes   : data,
                    bytesPerRow : bytesPerRow)
        return tex
    }
}
