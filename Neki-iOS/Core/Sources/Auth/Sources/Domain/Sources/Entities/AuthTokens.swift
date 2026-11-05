//
//  AuthTokens.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

/// 인증 과정에 사용되는 토큰
public struct AuthTokens: Codable, Sendable {
    public typealias Token = String

    public let accessToken: Token // 1시간
    public let refreshToken: Token // 30일
    public let expiredAt: Date
    
    public init(accessToken: Token, refreshToken: Token, issuedAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        expiredAt = issuedAt.addingTimeInterval(60 * 60)
    }

    public func isRefreshNeeded(at referenceDate: Date) -> Bool {
        referenceDate.addingTimeInterval(60 * 5) >= expiredAt
    }
}
