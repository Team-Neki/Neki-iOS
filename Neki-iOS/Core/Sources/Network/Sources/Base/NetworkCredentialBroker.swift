//
//  NetworkCredentialBroker.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/11/26.
//

import Foundation

/// 네트워크 요청에 사용되는 자격증명의 조회, 재발급 조율 및 종단 실패 전달 계약입니다.
protocol NetworkCredentialBroker: Sendable {
    var credentialGeneration: UUID { get async }

    func isCurrent(generation: UUID) async -> Bool
    func store(_ tokens: AuthTokens, matchingGeneration generation: UUID) async throws
    func removeCredentials(matchingGeneration generation: UUID) async throws -> Bool
    /// 인증 복구와 한 차례의 재시도를 조율합니다. 실제 HTTP 전송은 operation이 담당합니다.
    func performAuthenticatedRequest(
        using provider: any NetworkProvider,
        generation: UUID,
        operation: @Sendable (AuthTokens) async throws -> Data
    ) async throws -> Data
}
