//
//  AuthCredentialFailureHandling.swift
//  Neki-iOS
//
//  Created by SwainYun on 9/14/26.
//

/// 인증 복구 실패를 AuthClient에 전달합니다. 토큰 접근 및 세션 만료 판단은 수행하지 않습니다.
public protocol AuthCredentialFailureHandling: Sendable {
    func reportCredentialFailure(
        _ failure: AuthCredentialFailure,
        isCurrent: @escaping @Sendable () async -> Bool
    ) async
    func credentialFailures() async -> AsyncStream<AuthCredentialFailure>
}
