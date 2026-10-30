//
//  QRCodeDumpError.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/30/26.
//

enum QRCodeDumpError: Error {
    case invalidURL
    case invalidRedirectURL
    case fileCreationFailed
    case unavailableStorageCapacity
    case insufficientStorageCapacity
    case missingFileSize
    case responseTooLarge
    case stringDecodingFailed
    case unsupportedStringEncoding
    case missingUploadTicket
    case missingDocument
    case unsupportedUploadMethod
    case invalidUploadTicket
}
