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
    func store(_ tokens: AuthTokens) async throws
    func fetchStoredTokens() async throws -> AuthTokens
    func removeCredentials(matchingRevision revision: UUID) async throws -> Bool
    func removeCredentials(matchingGeneration generation: UUID) async throws -> Bool
    func authorizedCredentials(using provider: any NetworkProvider) async throws -> TokenStorageSnapshot
    func refresh(using provider: any NetworkProvider, credentials: TokenStorageSnapshot) async throws -> TokenStorageSnapshot
    func reportUnauthorized(_ credentials: TokenStorageSnapshot) async
    func failures() async -> AsyncStream<NetworkCredentialFailure>
}
