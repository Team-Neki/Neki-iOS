//
//  User.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

/// 사용자 정보
public struct User: Sendable {
    let nickname: String
    let providerType: ProviderType
}

/// 로그인된 사용자의 연결 정보
public struct UserSession {
    let user: User
    let tokens: AuthTokens
}
