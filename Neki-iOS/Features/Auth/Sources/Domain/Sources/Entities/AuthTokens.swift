//
//  AuthTokens.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

/// 인증 과정에 사용되는 토큰
public struct AuthTokens: Codable {
    public typealias Token = String
    
    let accessToken: Token
    let refreshToken: Token
    
    // TODO: 만료시각 정해지면 expiredDate 프로퍼티 추가
}
