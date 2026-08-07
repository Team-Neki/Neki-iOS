//
//  SocialLoginDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation

enum SocialLoginDTO {
    struct Request: Encodable {
        let idToken: String
        let platform: String?
    }

    struct Response: Decodable, TokenContainer {
        let accessToken: String
        let refreshToken: String
        let isNewUser: Bool

        func toEntity() -> AuthTokens { .init(accessToken: accessToken, refreshToken: refreshToken) }
    }
}
