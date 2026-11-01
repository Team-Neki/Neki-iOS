//
//  QRCodeDumpDocument.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/28/26.
//

import Foundation

struct QRCodeDumpDocument: Sendable, Equatable {
    let data: Data

    var byteCount: Int { data.count }
}

struct QRCodeDumpUploadTicket: Sendable, Equatable {
    let method: String
    let uploadTicket: String
    let contentType: String
}
