//
//  QRCodeDumpStorage.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/30/26.
//

import Dependencies
import Foundation

struct QRCodeDumpStorage: Sendable {
    var temporaryDirectoryURL: URL
    var availableCapacity: @Sendable (URL) throws -> Int64?
}

private enum QRCodeDumpStorageKey: DependencyKey {
    static let liveValue = QRCodeDumpStorage(temporaryDirectoryURL: FileManager.default.temporaryDirectory, availableCapacity: { url in
        try url.resourceValues(forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey])
            .volumeAvailableCapacityForOpportunisticUsage
    })
}

extension DependencyValues {
    var qrCodeDumpStorage: QRCodeDumpStorage {
        get { self[QRCodeDumpStorageKey.self] }
        set { self[QRCodeDumpStorageKey.self] = newValue }
    }
}
