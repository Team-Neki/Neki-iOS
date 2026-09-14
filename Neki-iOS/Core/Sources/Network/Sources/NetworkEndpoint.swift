//
//  NetworkEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/14/26.
//

import Foundation

enum NetworkEndpoint {
    case reissueToken(dto: ReissueTokenDTO.Request)
}


// MARK: - NetworkEndpoint + Endpoint

extension NetworkEndpoint: Endpoint {
    var authorizationType: AuthorizationType {
        switch self {
        case .reissueToken: return .reissue
        }
    }

    var contentType: HTTPContentType { .json }

    var path: String {
        switch self {
        case .reissueToken: return "auth/refresh"
        }
    }

    var method: HTTPMethodType {
        switch self {
        case .reissueToken: return .post
        }
    }

    var body: (any Encodable)? {
        switch self {
        case let .reissueToken(dto): return dto
        }
    }
}
