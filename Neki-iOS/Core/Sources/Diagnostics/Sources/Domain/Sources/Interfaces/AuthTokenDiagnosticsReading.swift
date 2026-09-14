//
//  AuthTokenDiagnosticsReading.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/14/26.
//

/// 진단 화면에 필요한 읽기 계약입니다. 저장·삭제·재발급 기능은 노출하지 않습니다.
protocol AuthTokenDiagnosticsReading: Sendable {
    func fetchStoredTokens() async throws -> AuthTokens
}
