//
//  CameraSesssion+Video.swift
//  MuseSky
//
//  Created by warren on 11/12/19.
//  Copyright © 2019 DeepMuse All rights reserved.
//

import Foundation

#if os(xrOS)
#else
import AVFoundation

extension MetCamera: AVCaptureVideoDataOutputSampleBufferDelegate {

    private func texture(_ sampleBuf: CMSampleBuffer) -> MTLTexture? {
        guard let textureCache else { return err("textureCache") }
        guard let imageBuf = sampleBuf.imageBuffer else { return err("imageBuf") }
        
        let width  = CVPixelBufferGetWidth(imageBuf)
        let height = CVPixelBufferGetHeight(imageBuf)
        var imageTex: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuf, nil, .bgra8Unorm, width, height, 0, &imageTex)

        guard let imageTex else { return err("imageTex") }
        guard let texture = CVMetalTextureGetTexture(imageTex) else { return err("get texture")}
        return texture
        
        func err(_ str: String) -> MTLTexture? {
            print("⁉️ texture(): err \(#function): \(str)")
            return nil
        }
    }

    public func captureOutput(_: AVCaptureOutput,
                              didOutput sampleBuf: CMSampleBuffer,
                              from _: AVCaptureConnection) {
        
        if let tex = texture(sampleBuf) {
            self.camTex = tex
        }
    }
    
}
#endif
