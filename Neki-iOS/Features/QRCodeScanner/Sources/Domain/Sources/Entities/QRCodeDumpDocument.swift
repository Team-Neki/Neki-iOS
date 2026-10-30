//
//  QRCodeDumpDocument.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/28/26.
//

import Foundation

struct QRCodeDumpDocument: Sendable, Equatable {
    let id: UUID
    let sourceURL: URL
    let finalURL: URL?
    let byteCount: Int64
}

struct QRCodeDumpUploadTicket: Sendable, Equatable {
    let method: String
    let expiresIn: String
    let uploadTicket: String
    let contentType: String
}
