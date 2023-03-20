//
//  FacePose.swift
//  Platonix
//
//  Created by warren on 2/18/23.
//  Copyright © 2023 com.deepmuse. All rights reserved.
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

public protocol MetFacePoseDelegate {
    func didUpdate(_ ciImage: CIImage)
}

open class MetFacePose: NSObject {

    let device: MTLDevice
    let pipeline: MetPipeline
   public let delegate: MetFacePoseDelegate?

    // The Vision requests and the handler to perform them.
    private var visionSequence: VNSequenceRequestHandler!
    private var faceRectangles: VNDetectFaceRectanglesRequest!
    private var personSegment: VNGeneratePersonSegmentationRequest!
    public var session: AVCaptureSession?

    private var didUpdate: MetFacePoseDelegate?
    private var angleColors: MetFaceAngleColors?

    public var ciContext: CIContext!
    var camSession: MetCamera!

    public var ciImage: CIImage? {
        didSet {
            if let ciImage {
                delegate?.didUpdate(ciImage)
            }
        }
    }

    public init(_ pipeline: MetPipeline,
         _ delegate: MetFacePoseDelegate? = nil) {

        self.pipeline = pipeline
        self.device = pipeline.device
        self.delegate = delegate

        super.init()
        
        ciContext = CIContext(mtlDevice: device)
        camSession = MetCamera(self, position: .front)
        camSession.startCamera()

        setupFacePose()
    }

    private func setupFacePose() {

        // The Vision requests and the handler to perform them.
        visionSequence = VNSequenceRequestHandler()
        personSegment = VNGeneratePersonSegmentationRequest()

        // Create a request to detect face rectangles.
        faceRectangles = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let face = request.results?.first as? VNFaceObservation else { return }
            // Generate RGB color intensity values for the face rectangle angles.
            self?.angleColors = MetFaceAngleColors(roll: face.roll, pitch: face.pitch, yaw: face.yaw)
        }
        faceRectangles.revision = VNDetectFaceRectanglesRequestRevision3

        // Create a request to segment a person from an image.
        personSegment = VNGeneratePersonSegmentationRequest()
        personSegment.qualityLevel = .balanced
        personSegment.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    private func processVideoFrame(_ pixelBuffer: CVPixelBuffer) {

        let faceMask = true // ??? platoOps.faceMask
        if  faceMask {
            // Perform the requests on the pixel buffer that contains the video frame.

            try? visionSequence.perform([faceRectangles, personSegment],
                                        on: pixelBuffer,
                                        orientation: .right)
            // Get the pixel buffer that contains the mask image.
            guard let maskBuffer =
                    personSegment.results?.first?.pixelBuffer else { return }

            ciImage = blend(original: pixelBuffer, mask: maskBuffer)
        } else {
            ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        }
    }

    private func blend(original framePixelBuffer: CVPixelBuffer,
                       mask maskPixelBuffer: CVPixelBuffer) -> CIImage? {

        guard let colors = angleColors else { return nil }

        // Create CIImage objects for the video frame and the segmentation mask.
        let originalImage = CIImage(cvPixelBuffer: framePixelBuffer).oriented(.right)
        var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

        // Scale the mask image to fit the bounds of the video frame.
        let scaleX = originalImage.extent.width / maskImage.extent.width
        let scaleY = originalImage.extent.height / maskImage.extent.height
        maskImage = maskImage.transformed(by: .init(scaleX: scaleX, y: scaleY))

        // Define RGB vectors for CIColorMatrix filter.
        let vectors = [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: colors.red),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: colors.green),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: colors.blue)
        ]

        // Create a colored background image.
        let backgroundImage = maskImage.applyingFilter("CIColorMatrix",
                                                       parameters: vectors)

        // Blend the original, background, and mask images.
        let blendFilter = CIFilter.blendWithRedMask()
        blendFilter.inputImage = originalImage
        blendFilter.backgroundImage = backgroundImage
        blendFilter.maskImage = maskImage

        // Set the new, blended image as current.
        return blendFilter.outputImage?.oriented(.left)
    }
}

// MARK: - Capture Video Data

extension MetFacePose: AVCaptureVideoDataOutputSampleBufferDelegate {
    @objc public func captureOutput(_ output: AVCaptureOutput,
                             didOutput sampleBuf: CMSampleBuffer,
                             from connection: AVCaptureConnection) {
        // Grab the image buffer frame from the camera output
        guard let imageBuf = sampleBuf.imageBuffer else { return }
        processVideoFrame(imageBuf)
    }
}

