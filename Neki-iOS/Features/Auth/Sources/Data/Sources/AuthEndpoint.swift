//
//  AuthEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation
import os

enum AuthEndpoint {
    case reissueToken
    case login(dto: SocialLoginDTO.Request, provider: ProviderType)
    case fetchUserInfo
}


// MARK: - AuthEndpoint + Endpoint

extension AuthEndpoint: Endpoint {
    var authorizationType: AuthorizationType {
        switch self {
        case .reissueToken: return .reissue
        case .login, .fetchUserInfo: return .bearer
        }
    }
    
    var contentType: HTTPContentType { .json }
    
    var baseURL: String {
        guard let baseURLString = Bundle.main.infoDictionary?["BASE_URL"] as? String else {
            Logger.data.fault("Base URL not found in Bundle")
            fatalError()
        }
        return baseURLString
    }
    
    var path: String {
        switch self {
        case .reissueToken: return "/auth/refresh"
        case let .login(_, provider): return "/auth/\(provider.name)/login"
        case .fetchUserInfo: return "/users/info"
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .reissueToken, .login: return .post
        case .fetchUserInfo: return .get
        }
    }
    
    var body: (any Encodable)? {
        switch self {
        case .reissueToken, .fetchUserInfo: return nil
        case let .login(dto, _): return dto
        }
    }
}
