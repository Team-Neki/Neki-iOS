//
//  CameraPreview.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/16/26.
//

import SwiftUI
import AVFoundation
import os

final class CameraView: UIView {
    var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var observation: NSKeyValueObservation?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    func stopSession() {
        observation?.invalidate()
        observation = nil
        rotationCoordinator = nil
        guard let session = session, session.isRunning else { return }
        Task.detached(priority: .background) { session.stopRunning() }
    }
    
    @MainActor
    func setupPreviewLayer(session: AVCaptureSession, device: AVCaptureDevice) {
        self.session = session
        
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
    
    func toggleTorch(on: Bool) {
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

struct CameraPreview: UIViewRepresentable {
    @Binding var isTorchOn: Bool
    
    let onScan: (String) -> Void
    
    init(isTorchOn: Binding<Bool>, onScan: @escaping (String) -> Void) {
        self._isTorchOn = isTorchOn
        self.onScan = onScan
    }
    
    func makeUIView(context: Context) -> CameraView {
        let cameraView = CameraView()
        Task { await context.coordinator.setupCamera(in: cameraView) }
        return cameraView
    }
    
    func updateUIView(_ uiView: CameraView, context: Context) {
        uiView.toggleTorch(on: isTorchOn)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    static func dismantleUIView(_ uiView: CameraView, coordinator: Coordinator) { uiView.stopSession() }
}


// MARK: - CameraPreview + Nested Types

extension CameraPreview {
    final class Coordinator: NSObject {
        private let parent: CameraPreview
        private let queue = DispatchQueue(label: "com.neki.camera.metadata.serialQueue")
        private var isScanning = true
        
        init(parent: CameraPreview) { self.parent = parent }
        
        func setupCamera(in view: CameraView) async {
            let session = AVCaptureSession()
            session.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(for: .video) else { return }
            
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { device.whiteBalanceMode = .continuousAutoWhiteBalance }
                device.unlockForConfiguration()
                
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input) }
                let output = AVCaptureMetadataOutput()
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    output.setMetadataObjectsDelegate(self, queue: queue)
                    output.metadataObjectTypes = output.availableMetadataObjectTypes.filter { $0 == .qr }
                }
                
                session.commitConfiguration()
                await view.setupPreviewLayer(session: session, device: device)
                session.startRunning()
            } catch {
                Logger.presentation.error("Camera setup failed: \(error)")
            }
        }
    }
}


// MARK: - CameraPreview.Coordinator + AVCaptureMetadataOutputObjectsDelegate

extension CameraPreview.Coordinator: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard isScanning else { return }
        
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue
        else { return }
        
        isScanning = false
        
        Task { @MainActor in parent.onScan(stringValue) }
    }
}
