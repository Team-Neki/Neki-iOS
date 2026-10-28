//
//  QRCodeDumpDocument.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/28/26.
//

import Foundation

struct QRCodeDumpDocument: Sendable, Equatable {
    let sourceURL: URL
    let finalURL: URL?
    let htmlData: Data

    var uploadData: Data {
        var comments = "<!-- source: \(sourceURL.absoluteString) -->\n"
        if let finalURL, finalURL != sourceURL {
            comments += "<!-- final: \(finalURL.absoluteString) -->\n"
        }

        let commentData = Data(comments.utf8)
        var data = Data()
        data.reserveCapacity(commentData.count + htmlData.count)
        data.append(commentData)
        data.append(htmlData)
        return data
    }
}

struct QRCodeDumpUploadTicket: Sendable, Equatable {
    let method: String
    let expiresIn: String
    let uploadTicket: String
    let contentType: String
}
