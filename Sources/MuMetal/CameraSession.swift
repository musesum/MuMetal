
import AVFoundation
import Metal
import UIKit

public final class CameraSession: NSObject {

    public static var shared = CameraSession()
    public override init() {

        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(captureSessionRuntimeError), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: nil)
        cameraCallback = self
    }
    var uiOrientation: UIInterfaceOrientation { get {
        UIApplication.shared.connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .first { $0.isKeyWindow }?.windowScene?.interfaceOrientation ?? .portrait
    }}

    var cameraTexture: MTLTexture?  // optional texture 2
    var cameraPosition: AVCaptureDevice.Position = .front
    var cameraState: CameraState = .waiting

    private var cameraSession = AVCaptureSession()
    private var cameraQueue = DispatchQueue(label: "CameraQueue", attributes: [])
    internal var textureCache: CVMetalTextureCache?

    private var device = MTLCreateSystemDefaultDevice()
    var cameraCallback: AVCaptureVideoDataOutputSampleBufferDelegate?

    init(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate? = nil) {
        self.cameraCallback = delegate
    }

    public func startCamera() {
        
        print("startCamera state: \(cameraState)")

        switch cameraState {
            case .waiting:

                requestCameraAccess()
                cameraQueue.async(execute: initCamera)

            case .ready, .stopped:

                cameraQueue.async {
                    self.cameraSession.startRunning()
                    self.updateOrientation()
                }
                cameraState = .streaming

            case .streaming: break
        }
        func initCamera() {

            cameraSession.beginConfiguration()
            initCaptureInput()
            initCaptureOutput()
            updateOrientation()
            cameraSession.commitConfiguration()

            initTextureCache()
            cameraSession.startRunning()
            cameraState = .streaming
        }
    }

    /// Stop the capture session.
    public func stopCamera() {
        cameraQueue.async {
            if self.cameraState != .stopped {

                self.cameraSession.stopRunning()
                self.cameraState = .stopped
            }
        }
    }

    public func setCameraOn(_ isOn: Bool) {

        if isOn {
            if cameraState != .streaming {
                startCamera()
            }
        } else {
            if cameraState == .streaming {
                stopCamera()
            }
        }
    }

    public func flipCamera() {

        cameraPosition = (cameraPosition == .front) ? .back : .front
        cameraSession.beginConfiguration()
        if let deviceInput = cameraSession.inputs.first as? AVCaptureDeviceInput {
            cameraSession.removeInput(deviceInput)
            initCaptureInput()
            updateOrientation()
        }
        cameraSession.commitConfiguration()
    }

    /// Current capture input device.
    internal var inputDevice: AVCaptureDeviceInput? {
        didSet {
            if let oldValue {
                print("   \(#function): \(oldValue) -> \(inputDevice!)")
                cameraSession.removeInput(oldValue)
            }
            if let inputDevice {
                cameraSession.addInput(inputDevice)
            }
        }
    }

    /// Current capture output data stream.
    internal var output: AVCaptureVideoDataOutput? {
        didSet {
            if let oldValue {
                print("   \(#function): \(oldValue) -> \(output!)")
                cameraSession.removeOutput(oldValue)
            }
            if let output {
                cameraSession.addOutput(output)
            }
        }
    }

    /// Requests access to camera hardware.
    fileprivate func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if !granted {
                print("⁉️ \(#function) not granted")
            }  else if self.cameraState != .streaming {
                self.cameraState = .ready
            }
        }
    }

    /// camera frames to textures.
    private func initTextureCache() {

        guard let device,
              CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess
        else {
            return print("⁉️ err \(#function): failed")
        }
    }

    //// initializes capture input device with media type and device position.
    fileprivate func initCaptureInput() {

        cameraSession.sessionPreset = .hd1920x1080

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: AVMediaType.video,
                                                   position: cameraPosition)
        else { return err ("AVCaptureDevice") }

        guard let captureInput = try? AVCaptureDeviceInput(device: device)
        else { return err ("AVCaptureDeviceInput") }

        guard cameraSession.canAddInput(captureInput)
        else { return err ("canAddInput") }

        self.inputDevice = captureInput

        func err(_ str: String) {
            print("⁉️ err \(#function): \(str)")
        }
    }

    func updateOrientation() {

        guard let connection = output?.connection(with: .video) else { return err("connection") }
        DispatchQueue.main.async {

            var orientation = AVCaptureVideoOrientation.portrait
            switch self.uiOrientation {
                case .portrait:             orientation = .portrait
                case .portraitUpsideDown:   orientation = .portraitUpsideDown
                case .landscapeLeft:        orientation = .landscapeLeft
                case .landscapeRight:       orientation = .landscapeRight
                default: return err("\(self.uiOrientation)")
            }
            connection.videoOrientation = orientation
            connection.isVideoMirrored = (self.cameraPosition == .front)
        }
        func err(_ str: String) {
            print("⁉️ err \(#function): \(str)")
        }
    }

    /// initialize capture output data stream.
    fileprivate func initCaptureOutput() {
        guard let cameraCallback else { return err("delegate == nil")}
        let out = AVCaptureVideoDataOutput()
        out.videoSettings =  [ kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA ]
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(cameraCallback,
                                    queue: cameraQueue)
        if cameraSession.canAddOutput(out) {
            self.output = out
        } else {
            err("add output failed")
        }
        func err(_ str: String) { print("⁉️ err \(#function): \(str)") }
    }
    /// `AVCaptureSessionRuntimeErrorNotification` callback.
    @objc fileprivate func captureSessionRuntimeError() {

        if cameraState == .streaming {
            print("⁉️ err \(#function)") }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

