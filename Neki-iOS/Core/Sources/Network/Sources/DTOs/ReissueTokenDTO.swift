//
//  ReissueTokenDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation

enum ReissueTokenDTO {
    struct Request: Encodable {
        let refreshToken: String
    }

    struct Response: Decodable, TokenContainer {
        let accessToken: String
        let refreshToken: String

        func toEntity() -> AuthTokens { .init(accessToken: accessToken, refreshToken: refreshToken) }
    }
}
