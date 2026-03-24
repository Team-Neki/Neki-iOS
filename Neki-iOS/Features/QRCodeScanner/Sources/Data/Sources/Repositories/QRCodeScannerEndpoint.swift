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
        }
    }
    
    public var path: String {
        switch self {
        case .notifyUnsupportedBrand: return ""
        }
    }
    
    public var method: HTTPMethodType {
        switch self {
        case .notifyUnsupportedBrand: return .post
        }
    }
    
    public var authorizationType: AuthorizationType { return .none }
    
    public var contentType: HTTPContentType { return .json }
    
    public var body: (any Encodable)? {
        switch self {
        case let .notifyUnsupportedBrand(url, user): return DiscordWebhookDTO.Request(unsupportedURL: url, user: user)
        }
    }
}
