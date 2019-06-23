//
//  ScanViewController.swift
//  PretixScan
//
//  Created by Daniel Jilg on 27.03.19.
//  Copyright © 2019 rami.io. All rights reserved.
//

import AVFoundation
import UIKit

/// Generic ViewController Superclass to scan barcodes and QR codes.
///
/// To subclass:
/// - subclass and override the `found()` method to know what to do with found QR Codes
/// - set `shouldScan` to `true` to start scanning, to `false` to stop scanning after you found something
class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    /// Period between scans when the timer will not fire
    var gracePeriod: TimeInterval = 2

    /// If `true`, scanning will be active
    var shouldScan = false {
        didSet {
            if shouldScan {
                startScanning()
            } else {
                stopScanning()
            }
        }
    }

    private var lastFoundAt: Date = Date.distantPast
    private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()

    private var avCaptureDevice: AVCaptureDevice?
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!

    private var tapGestureRecognizer: UITapGestureRecognizer?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.darkGray
        captureSession = AVCaptureSession()

        avCaptureDevice = AVCaptureDevice.default(for: .video)
        guard let videoCaptureDevice = avCaptureDevice else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Tap Gestures
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleFlash))
        view.addGestureRecognizer(tapGestureRecognizer!)
    }

    func failed() {
        EventLogger.log(event: "Failed to create Capture Session", category: .avCaptureDevice, level: .error, type: .fault)
        captureSession = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if shouldScan {
            startScanning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    private func startScanning() {
        guard AVCaptureDevice.default(for: .video) != nil else { return }
        if captureSession?.isRunning == false {
            captureSession.startRunning()
        }
    }

    private func stopScanning() {
        guard AVCaptureDevice.default(for: .video) != nil else { return }
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {

        guard -(lastFoundAt.timeIntervalSinceNow) > gracePeriod else { return }
        lastFoundAt = Date()
        guard let metadataObject = metadataObjects.first else { return }
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
        guard let stringValue = readableObject.stringValue else { return }

        vibrate()
        // flashView()
        found(code: stringValue)
    }

    func vibrate() {
        selectionFeedbackGenerator.selectionChanged()
    }

    func flashView() {
        if let window = self.view {

            let flashingView = UIView(frame: window.bounds)
            flashingView.backgroundColor = UIColor.white
            flashingView.alpha = 1

            window.addSubview(flashingView)
            UIView.animate(withDuration: 1, animations: {
                flashingView.alpha = 0.0
            }, completion: { _ in
                flashingView.removeFromSuperview()
            })
        }
    }

    /// Toggle the Flashlight on and off if possible
    ///
    /// https://stackoverflow.com/a/27334447/54547
    @objc func toggleFlash() {
        guard let device = avCaptureDevice else { return }
        guard device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if device.torchMode == .on {
                device.torchMode = .off
            } else {
                do {
                    try device.setTorchModeOn(level: 1.0)
                } catch {
                    EventLogger.log(event: "\(error.localizedDescription)", category: .avCaptureDevice, level: .error, type: .fault)
                }
            }

            device.unlockForConfiguration()
        } catch {
            EventLogger.log(event: "\(error.localizedDescription)", category: .avCaptureDevice, level: .error, type: .fault)
        }
    }

    // Override this method in yuor subclass
    func found(code: String) {
        print(code)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
