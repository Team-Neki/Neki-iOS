//
//  CameraPreview.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/16/26.
//

import SwiftUI
import AVFoundation
import os

final actor CameraManager {
    enum Status {
        case notConfigured
        case configured
        case running
        case stopped
    }
    
    enum CameraError: Error {
        case deviceUnavailable
        case inputError
        case outputError
    }
    
    private var status: Status = .notConfigured
    private let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private let device = AVCaptureDevice.default(for: .video)
    private let metadataQueue = DispatchQueue(label: "com.neki.camera.metadata")
    private var delegateProxy: CameraDelegateProxy?
    
    func configure(onScan: @escaping @MainActor (String) -> Void) throws(CameraError) -> (AVCaptureSession, AVCaptureDevice) {
        guard status == .notConfigured else {
            guard let device else { throw .deviceUnavailable }
            return (session, device)
        }
        guard let device = device,
              let input = try? AVCaptureDeviceInput(device: device)
        else { throw .deviceUnavailable }
        
        session.beginConfiguration()
        
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw .inputError
        }
        session.addInput(input)
        
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw .outputError
        }
        session.addOutput(output)
        
        let proxy = CameraDelegateProxy(onScan: onScan)
        delegateProxy = proxy
        output.setMetadataObjectsDelegate(proxy, queue: metadataQueue)
        guard output.availableMetadataObjectTypes.contains(.qr) else { throw .outputError }
        output.metadataObjectTypes = [.qr]
        
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { device.whiteBalanceMode = .continuousAutoWhiteBalance }
            device.unlockForConfiguration()
        } catch {
            session.commitConfiguration()
            Logger.presentation.debug("Camera Configuration Lost: \(error)")
        }
        
        session.commitConfiguration()
        status = .configured
        return (session, device)
    }
    
    func start() {
        guard status == .configured || status == .stopped else { return }
        guard session.isRunning == false else { return }
        session.startRunning()
        status = .running
    }
    
    func stop() {
        guard status == .running else { return }
        guard session.isRunning else { return }
        session.stopRunning()
        status = .stopped
    }
    
    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            Logger.presentation.error("Torch could not be used")
        }
    }
}

private final class CameraDelegateProxy: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let onScan: @MainActor (String) -> Void
    
    init(onScan: @escaping @MainActor (String) -> Void) { self.onScan = onScan }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue
        else { return }
        
        Task { @MainActor in onScan(stringValue) }
    }
}

final class CameraView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var observation: NSKeyValueObservation?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    @MainActor
    func setupPreviewLayer(session: AVCaptureSession, device: AVCaptureDevice) {
        guard previewLayer == nil else { return }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        self.previewLayer = layer
        
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        self.rotationCoordinator = coordinator
        layer.connection?.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        
        observation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] coordinator, _ in
            guard let self else { return }
            Task { @MainActor in self.previewLayer?.connection?.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview }
        }
    }
    
    func cleanup() {
        observation?.invalidate()
        observation = nil
        rotationCoordinator = nil
    }
}

struct CameraPreview: UIViewRepresentable {
    let isTorchOn: Bool
    let isActive: Bool
    let onScan: (String) -> Void
    
    func makeUIView(context: Context) -> CameraView {
        let cameraView = CameraView()
        Task {
            guard let (session, device) = try? await context.coordinator.cameraManager.configure(onScan: { code in
                onScan(code)
            }) else { return }
            
            cameraView.setupPreviewLayer(session: session, device: device)
            
            guard isActive else { return }
            await context.coordinator.cameraManager.start()
        }
        return cameraView
    }
    
    func updateUIView(_ uiView: CameraView, context: Context) {
        Task {
            let manager = context.coordinator.cameraManager
            
            if isActive {
                await manager.start()
                await manager.setTorch(on: isTorchOn)
            } else {
                await manager.stop()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    static func dismantleUIView(_ uiView: CameraView, coordinator: Coordinator) {
        uiView.cleanup()
        Task { await coordinator.cameraManager.stop() }
    }
}


// MARK: - Nested Types

extension CameraPreview {
    final class Coordinator {
        let cameraManager = CameraManager()
    }
}
