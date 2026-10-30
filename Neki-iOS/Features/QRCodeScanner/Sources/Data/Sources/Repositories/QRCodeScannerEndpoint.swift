//
//  QRCodeScannerEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 3/24/26.
//

import Foundation
import os
import UniformTypeIdentifiers

public enum QRCodeScannerEndpoint {
    case notifyUnsupportedBrand(url: URL, user: User)
    case issueDumpUploadTicket
}


// MARK: - QRCodeScannerEndpoint + Endpoint

extension QRCodeScannerEndpoint: Endpoint {
    public var baseURL: String {
        switch self {
        case .notifyUnsupportedBrand:
            guard let webhookURLString = Bundle.main.infoDictionary?["QR_WEBHOOK_URL"] as? String else {
                Logger.data.fault("QR_WEBHOOK_URL을 번들에서 찾을 수 없음.")
                return ""
            }
            return webhookURLString
        case .issueDumpUploadTicket:
            guard let baseURLString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
                Logger.data.fault("BASE_URL을 번들에서 찾을 수 없음.")
                return ""
            }
            return baseURLString
        }
    }
    
    public var path: String {
        switch self {
        case .notifyUnsupportedBrand: return ""
        case .issueDumpUploadTicket: return "media/qr-dumps/upload"
        }
    }
    
    public var method: HTTPMethodType {
        switch self {
        case .notifyUnsupportedBrand, .issueDumpUploadTicket: return .post
        }
    }
    
    public var authorizationType: AuthorizationType {
        switch self {
        case .issueDumpUploadTicket: return .bearer
        case .notifyUnsupportedBrand: return .none
        }
    }
    
    public var contentType: HTTPContentType {
        switch self {
        case .notifyUnsupportedBrand, .issueDumpUploadTicket: return .json
        }
    }
    
    public var body: (any Encodable)? {
        switch self {
        case let .notifyUnsupportedBrand(url, user): return DiscordWebhookDTO.Request(unsupportedURL: url, user: user)
        case .issueDumpUploadTicket: return nil
        }
    }

    public var networkLogPolicy: NetworkLogPolicy {
        switch self {
        case .notifyUnsupportedBrand, .issueDumpUploadTicket: return .standard
        }
    }
}

struct QRCodeDumpDownloadEndpoint: FileDownloadEndpoint {
    static let maximumObjectSize: Int64 = 5 * 1_024 * 1_024 * 1_024 * 1_024

    let sourceURL: URL
    let maximumBodySize: Int64

    var baseURL: String { sourceURL.absoluteString }
    var path: String { "" }
    var method: HTTPMethodType { .get }
    var contentType: HTTPContentType { .json }
    var body: (any Encodable)? { nil }
    var networkLogPolicy: NetworkLogPolicy { .metadataOnly }
    var responseConstraint: HTTPResponseConstraint {
        HTTPResponseConstraint(allowedContentTypes: [.html], maximumBodySize: maximumBodySize)
    }
}

struct QRCodeDumpUploadEndpoint: FileUploadEndpoint {
    let presignedURL: String
    let uploadMethod: HTTPMethodType
    let uploadContentType: String

    var baseURL: String { presignedURL }
    var path: String { "" }
    var method: HTTPMethodType { uploadMethod }
    var contentType: HTTPContentType { .custom(uploadContentType) }
    var body: (any Encodable)? { nil }
    var networkLogPolicy: NetworkLogPolicy { .metadataOnly }
}
