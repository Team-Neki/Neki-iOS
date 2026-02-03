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
    
    case withdraw
    case editNickname(dto: EditNicknameDTO.Request)
    case editProfileImage(dto: EditProfileImageDTO.Request)
    case fetchUserInfo
}


// MARK: - AuthEndpoint + Endpoint

extension AuthEndpoint: Endpoint {
    var authorizationType: AuthorizationType {
        switch self {
        case .reissueToken: return .reissue
        case .login: return .none
        case .withdraw, .editNickname, .editProfileImage, .fetchUserInfo: return .bearer
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
        case .reissueToken: return "auth/refresh"
        case let .login(_, provider): return "auth/\(provider.name)/login"
        case .withdraw: return "users/me"
        case .editNickname: return "users/me"
        case .editProfileImage: return "users/me/profile-image"
        case .fetchUserInfo: return "users/info"
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .reissueToken, .login: return .post
        case .withdraw: return .delete
        case .editNickname, .editProfileImage: return .patch
        case .fetchUserInfo: return .get
        }
    }
    
    var body: (any Encodable)? {
        switch self {
        case .reissueToken, .fetchUserInfo, .withdraw: return nil
        case let .login(dto, _): return dto
        case let .editNickname(dto): return dto
        case let .editProfileImage(dto): return dto
        }
    }
}
