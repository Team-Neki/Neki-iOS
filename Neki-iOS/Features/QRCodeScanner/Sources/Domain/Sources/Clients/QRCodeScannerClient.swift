//
//  QRCodeScannerClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/16/26.
//

import Foundation
import AVFoundation
import ComposableArchitecture

struct QRScannerClient {
    var checkAuthorizationStatus: @Sendable () -> AVAuthorizationStatus
    var requestAccess: @Sendable () async -> Bool
}

extension QRScannerClient: DependencyKey {
    static let liveValue = Self {
        AVCaptureDevice.authorizationStatus(for: .video)
    } requestAccess: {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

extension DependencyValues {
    var qrScannerClient: QRScannerClient {
        get { self[QRScannerClient.self] }
        set { self[QRScannerClient.self] = newValue }
    }
}
