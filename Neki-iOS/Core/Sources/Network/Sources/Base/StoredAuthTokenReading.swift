//
//  StoredAuthTokenReading.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation

/// 저장된 토큰을 그대로 읽는 계약입니다. 재발급과 인증 실패 보고는 하지 않습니다.
/// - Note: 토큰이 있을 때만 붙이고 없으면 인증 없이 보내는 요청(서버 로그)에 씁니다.
protocol StoredAuthTokenReading: Sendable {
    func fetchStoredTokens() async throws -> AuthTokens
}
