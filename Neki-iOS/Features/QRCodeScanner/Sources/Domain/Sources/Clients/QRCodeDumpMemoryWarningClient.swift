//
//  QRCodeDumpMemoryWarningClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/30/26.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct QRCodeDumpMemoryWarningClient {
    var events: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
}

extension DependencyValues {
    var qrCodeDumpMemoryWarningClient: QRCodeDumpMemoryWarningClient {
        get { self[QRCodeDumpMemoryWarningClient.self] }
        set { self[QRCodeDumpMemoryWarningClient.self] = newValue }
    }
}
