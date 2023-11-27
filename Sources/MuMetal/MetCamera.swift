
import AVFoundation
import Metal
import UIKit
#if os(visionOS)
#else
public final class MetCamera: NSObject {

    public static var shared = MetCamera(nil, position: .front)
    
    var uiOrientation: UIInterfaceOrientation { get {
        UIApplication.shared.connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .first { $0.isKeyWindow }?.windowScene?.interfaceOrientation ?? .portrait
    }}

    var camTex: MTLTexture?  // optional texture 2
    var camPos: AVCaptureDevice.Position = .front
    var camState: MetCameraState = .waiting

    private var camSession = AVCaptureSession()
    private var camQueue = DispatchQueue(label: "CameraQueue", attributes: [])
    internal var textureCache: CVMetalTextureCache?

    private var device = MTLCreateSystemDefaultDevice()
    var camDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?

    public init(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate?,
                position: AVCaptureDevice.Position ) {

        self.camDelegate = delegate
        self.camPos = position
        super.init()

        camDelegate = camDelegate ?? self

        NotificationCenter.default.addObserver(self, selector: #selector(captureSessionRuntimeError), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: nil)
    }
    public var hasNewTex: Bool {
        return camState == .streaming && camTex != nil
    }
    public func startCamera() {
        
        print("startCamera state: \(camState)")

        switch camState {
            case .waiting:

                requestCameraAccess()
                camQueue.async(execute: initCamera)

            case .ready, .stopped:

                camQueue.async {
                    self.camSession.startRunning()
                    self.updateOrientation()
                }
                camState = .streaming

            case .streaming: break
        }
        func initCamera() {

            camSession.beginConfiguration()
            initCaptureInput()
            initCaptureOutput()
            updateOrientation()
            camSession.commitConfiguration()

            initTextureCache()
            camSession.startRunning()
            camState = .streaming
        }
    }

    /// Stop the capture session.
    public func stopCamera() {
        camQueue.async {

            if  self.camState != .stopped {

                self.camSession.stopRunning()
                self.camState = .stopped
            }
        }
    }

    public func setCameraOn(_ isOn: Bool) {

        if isOn {
            if camState != .streaming {
                startCamera()
            }
        } else {
            if camState == .streaming {
                stopCamera()
            }
        }
    }

    public func facing(_ front: Bool) {

        camPos = front ? .front : .back
        camSession.beginConfiguration()
        if let deviceInput = camSession.inputs.first as? AVCaptureDeviceInput {
            camSession.removeInput(deviceInput)
            initCaptureInput()
            updateOrientation()
        }
        camSession.commitConfiguration()
    }

    /// Current capture input device.
    internal var inputDevice: AVCaptureDeviceInput? {
        didSet {
            if let oldValue {
                print("   \(#function): \(oldValue) -> \(inputDevice!)")
                camSession.removeInput(oldValue)
            }
            if let inputDevice {
                camSession.addInput(inputDevice)
            }
        }
    }

    /// Current capture output data stream.
    internal var output: AVCaptureVideoDataOutput? {
        didSet {
            if let oldValue {
                print("   \(#function): \(oldValue) -> \(output!)")
                camSession.removeOutput(oldValue)
            }
            if let output {
                camSession.addOutput(output)
            }
        }
    }

    /// Requests access to camera hardware.
    fileprivate func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if !granted {
                print("⁉️ \(#function) not granted")
            }  else if self.camState != .streaming {
                self.camState = .ready
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

        camSession.sessionPreset = .hd1920x1080

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: AVMediaType.video,
                                                   position: camPos)
        else { return err ("AVCaptureDevice") }

        guard let captureInput = try? AVCaptureDeviceInput(device: device)
        else { return err ("AVCaptureDeviceInput") }

        guard camSession.canAddInput(captureInput)
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
            connection.isVideoMirrored = (self.camPos == .front)
        }
        func err(_ str: String) {
            print("⁉️ err updateOrientation: \(str)")
        }
    }

    /// initialize capture output data stream.
    fileprivate func initCaptureOutput() {
        guard let camDelegate else { return err("delegate == nil")}
        let out = AVCaptureVideoDataOutput()
        out.videoSettings =  [ kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA ]
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(camDelegate,
                                    queue: camQueue)
        if camSession.canAddOutput(out) {
            self.output = out
        } else {
            err("add output failed")
        }
        func err(_ str: String) { print("⁉️ err initCaptureOutput: \(str)") }
    }
    /// `AVCaptureSessionRuntimeErrorNotification` callback.
    @objc fileprivate func captureSessionRuntimeError() {

        if camState == .streaming {
            print("⁉️ captureSessionRuntimeError") }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
#endif
