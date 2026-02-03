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
//    public var refreshNeeded: Bool { Date.now.addingTimeInterval(60 * 5) >= expiredAt } // 만료 5분 전
    public var refreshNeeded: Bool { Date.now == expiredAt }
    
    public init(accessToken: Token, refreshToken: Token) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        expiredAt = Date(timeIntervalSinceNow: 60 * 60) // 1시간
    }
}
