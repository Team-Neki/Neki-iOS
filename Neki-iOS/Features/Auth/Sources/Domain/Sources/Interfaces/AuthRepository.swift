//
//  AuthRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation

public enum AuthRepositoryError: Error {
    case networkError(NetworkError)
    case decodingError
    case unauthorized
    case userNotFound
}

public protocol AuthRepository {
    /// 로그인/회원가입, idToken으로 서비스 토큰을 확보
    func login(idToken: String, provider: ProviderType) async throws(AuthRepositoryError) -> AuthTokens
    /// 사용자 정보 조회
    func fetchUser() async throws(AuthRepositoryError) -> User
    /// 회원탈퇴
    func withdraw() async throws(AuthRepositoryError) -> Void
    /// 로그아웃
    func logout() async throws(AuthRepositoryError) -> Void
    
    func updateProfile(nickname: String?, profileImage: Data?) async throws(AuthRepositoryError) -> Void
}
