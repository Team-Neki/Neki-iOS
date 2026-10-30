//
//  QRCodeDumpError.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/30/26.
//

enum QRCodeDumpError: Error {
    case invalidURL
    case invalidResponse
    case invalidRedirectURL
    case responseTooLarge
    case stringDecodingFailed
    case missingUploadTicket
    case unsupportedUploadMethod
    case invalidUploadTicket
}
