//
//  AuthRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation

public enum AuthRepositoryError: Error {
    case networkError(NetworkError)
    case unknown
    case unauthorized
    case userNotFound
}

public protocol AuthRepository {
    /// 로그인/회원가입, idToken으로 서비스 토큰을 확보
    func login(idToken: String, provider: ProviderType, platform: String) async throws(AuthRepositoryError) -> AuthTokens
    /// 사용자 정보 조회
    func fetchUser() async throws(AuthRepositoryError) -> User
    /// 회원탈퇴
    func withdraw() async throws(AuthRepositoryError) -> Void
    /// 로그아웃
    func logout() async throws(AuthRepositoryError) -> Void
    /// 프로필 편집
    func updateProfile(nickname: String?, profileImageID: Int?) async throws(AuthRepositoryError) -> Void
    /// 자동 로그인 (유저 세션 복구)
    func restoreSession() async throws(AuthRepositoryError) -> User
}
