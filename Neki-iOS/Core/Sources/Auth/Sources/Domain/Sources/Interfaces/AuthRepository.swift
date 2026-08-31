//
//  AuthRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation

public enum ProfileImageEditAction: Sendable, Equatable {
    public typealias ImageID = Int
    
    /// 새로운 이미지로 변경하기 (S3 업로드 필요)
    case update(ImageID)
    /// 기본 이미지로 변경
    case delete
    /// 기존 이미지 유지
    case keep
}

public protocol AuthRepository: Sendable {
    /// 요청에 사용할 수 없었던 자격증명을 관찰합니다. 세션 만료 정책은 적용하지 않습니다.
    func credentialFailures() async -> AsyncStream<AuthCredentialFailure>
    /// 실패한 자격증명이 아직 저장되어 있을 때만 삭제합니다. 다른 자격증명은 변경하지 않습니다.
    func removeCredentials(matching failure: AuthCredentialFailure) async -> AuthCredentialFailure.RemovalResult
    /// 로그인/회원가입, idToken으로 서비스 토큰을 확보
    func login(idToken: String, provider: ProviderType) async throws(AuthRepositoryError) -> (tokens: AuthTokens, registrationStatus: RegistrationStatus)
    /// 사용자 정보 조회
    func fetchUser() async throws(AuthRepositoryError) -> User
    /// 회원탈퇴
    func withdraw() async throws(AuthRepositoryError) -> Void
    /// 로그아웃
    func logout() async throws(AuthRepositoryError) -> Void
    /// 프로필 편집
    func updateProfile(nickname: String?, editAction: ProfileImageEditAction) async throws(AuthRepositoryError) -> Void
    /// 자동 로그인 (유저 세션 복구)
    func restoreSession() async throws(AuthRepositoryError) -> User
    /// 로컬 인증 토큰 조회
    func fetchStoredTokens() async -> AuthTokens?
    /// 이용약관 목록 조회
    func fetchTerms() async throws(AuthRepositoryError) -> [Term]
    /// 이용약관 동의
    func agreeWithTerms(agreements: [UserAgreement]) async throws(AuthRepositoryError) -> Void
    /// 마케팅 수신 동의 변경
    func updateMarketingConsent(isAgreed: Bool) async throws(AuthRepositoryError) -> Void
}
