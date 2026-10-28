//
//  QRCodeDumpRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/28/26.
//

import Foundation
import Dependencies

protocol QRCodeDumpRepository {
    func fetchHTMLDocument(from sourceURL: URL) async throws -> QRCodeDumpDocument
    func issueUploadTicket() async throws -> QRCodeDumpUploadTicket
    func upload(_ data: Data, with ticket: QRCodeDumpUploadTicket) async throws
}

private enum QRCodeDumpRepositoryKey: DependencyKey {
    static let liveValue: any QRCodeDumpRepository = DefaultQRCodeDumpRepository()
}

extension DependencyValues {
    var qrCodeDumpRepository: any QRCodeDumpRepository {
        get { self[QRCodeDumpRepositoryKey.self] }
        set { self[QRCodeDumpRepositoryKey.self] = newValue }
    }
}
