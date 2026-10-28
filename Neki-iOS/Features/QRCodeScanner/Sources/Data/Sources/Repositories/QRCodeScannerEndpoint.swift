//
//  QRCodeScannerEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 3/24/26.
//

import Foundation
import os

public enum QRCodeScannerEndpoint {
    case notifyUnsupportedBrand(url: URL, user: User)
    case fetchDump(url: URL)
    case issueDumpUploadTicket
    case uploadDump(
        presignedURL: String,
        method: HTTPMethodType,
        contentType: String,
        data: Data
    )
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
        case let .fetchDump(url):
            return url.absoluteString
        case .issueDumpUploadTicket:
            guard let baseURLString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
                Logger.data.fault("BASE_URL을 번들에서 찾을 수 없음.")
                return ""
            }
            return baseURLString
        case let .uploadDump(presignedURL, _, _, _):
            return presignedURL
        }
    }
    
    public var path: String {
        switch self {
        case .notifyUnsupportedBrand, .fetchDump, .uploadDump: return ""
        case .issueDumpUploadTicket: return "media/qr-dumps/upload"
        }
    }
    
    public var method: HTTPMethodType {
        switch self {
        case .fetchDump: return .get
        case .notifyUnsupportedBrand, .issueDumpUploadTicket: return .post
        case let .uploadDump(_, method, _, _): return method
        }
    }
    
    public var authorizationType: AuthorizationType {
        switch self {
        case .issueDumpUploadTicket: return .bearer
        case .notifyUnsupportedBrand, .fetchDump, .uploadDump: return .none
        }
    }
    
    public var contentType: HTTPContentType {
        switch self {
        case .notifyUnsupportedBrand, .fetchDump, .issueDumpUploadTicket: return .json
        case let .uploadDump(_, _, contentType, _): return .custom(contentType)
        }
    }
    
    public var body: (any Encodable)? {
        switch self {
        case let .notifyUnsupportedBrand(url, user): return DiscordWebhookDTO.Request(unsupportedURL: url, user: user)
        case .fetchDump, .issueDumpUploadTicket: return nil
        case let .uploadDump(_, _, _, data): return data
        }
    }

    public var networkLogPolicy: NetworkLogPolicy {
        switch self {
        case .fetchDump, .uploadDump: return .metadataOnly
        case .notifyUnsupportedBrand, .issueDumpUploadTicket: return .standard
        }
    }
}
