//
//  QRCodeDumpUploadTicketDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/28/26.
//

import Foundation

enum QRCodeDumpUploadTicketDTO {
    struct Response: Decodable {
        let method: String
        let expiresIn: String
        let uploadTicket: String
        let contentType: String

        func toEntity() -> QRCodeDumpUploadTicket {
            QRCodeDumpUploadTicket(
                method: method,
                expiresIn: expiresIn,
                uploadTicket: uploadTicket,
                contentType: contentType
            )
        }
    }
}
