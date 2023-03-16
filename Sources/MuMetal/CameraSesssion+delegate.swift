//
//  CameraSesssion+Video.swift
//  MuseSky
//
//  Created by warren on 11/12/19.
//  Copyright © 2019 DeepMuse All rights reserved.
//

import Foundation
import AVFoundation

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /**
     Converts a sample buffer received from camera to a Metal texture
     /Applications
     - Parameters:
       - sampleBuffer: Sample buffer
       - textureCache: Texture cache
       - planeIndex:   Index of the plane for planar buffers. Defaults to 0.
       - pixelFormat:  Metal pixel format. Defaults to `.bgra8Unorm`.

     - returns: Metal texture or nil
    */
    private func texture(_ sampleBuf: CMSampleBuffer?,
                         _ textureCache: CVMetalTextureCache?,
                         planeIndex: Int = 0,
                         pixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLTexture?
    {
        guard let sampleBuf else { return err("sampleBuf") }
        guard let textureCache else { return err("textureCache") }
        guard let imageBuf = CMSampleBufferGetImageBuffer(sampleBuf) else { return err("imageBuf") }

        let isPlanar = CVPixelBufferIsPlanar(imageBuf)
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(imageBuf, planeIndex) : CVPixelBufferGetWidth(imageBuf)
        let height = isPlanar ? CVPixelBufferGetHeightOfPlane(imageBuf, planeIndex) : CVPixelBufferGetHeight(imageBuf)

        var imageTex: CVMetalTexture?
        _ = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuf, nil, pixelFormat, width, height, planeIndex, &imageTex)
        guard let imageTex else { return err("imageTex") }
        guard let texture = CVMetalTextureGetTexture(imageTex) else { return err("get texture")}
        return texture
        
        func err(_ str: String) -> MTLTexture? {
            print("⁉️ texture(): err \(#function): \(str)")
            return nil
        }
    }

    public func captureOutput(_ captureOutput: AVCaptureOutput,
                              didOutput sampleBuf: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        
        if let tex = texture(sampleBuf, textureCache) {
            self.cameraTexture = tex
        }
    }
    
}
