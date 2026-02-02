//
//  AuthClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/24/26.
//

import Foundation
import Dependencies
import DependenciesMacros
import AuthenticationServices
import KakaoSDKAuth
import KakaoSDKUser
import KakaoSDKCert
import KakaoSDKCommon
import os

@DependencyClient
public struct AuthClient {
    public var loginWithApple: @Sendable (_ idToken: Data) async throws -> User
    public var loginWithKakao: @Sendable () async throws -> User
    public var autoLogin: @Sendable () async throws -> User
    public var signOut: @Sendable () async throws -> Void
    public var withdraw: @Sendable () async throws -> Void
    public var updateProfile: @Sendable (_ nickname: String?, _ profileImage: Data?) async throws -> Void
    public var handleKakaoOpenURL: @Sendable (_ url: URL) -> Void
}

extension AuthClient: DependencyKey {
    public static var liveValue: AuthClient = {
        let kakaoSDKHelper = KakaoSDKHelper()
        @Dependency(\.authRepository) var authRepository
        @Dependency(\.imageUploadRepository) var imageUploadRepository
        
        @Sendable func loginWithApple(idToken: Data) async throws -> User {
            guard let idTokenString = String(data: idToken, encoding: .utf8) else {
                throw AuthClientError.invalidClientToken
            }
            
            do {
                _ = try await authRepository.login(idToken: idTokenString, provider: .apple)
                return try await authRepository.fetchUser()
            } catch {
                throw AuthClient.mapError(error)
            }
        }
        
        @Sendable func loginWithKakao() async throws -> User {
            do {
                let idToken = try await kakaoSDKHelper.login()
                _ = try await authRepository.login(idToken: idToken, provider: .kakao)
                return try await authRepository.fetchUser()
            } catch let error as AuthRepositoryError {
                throw AuthClient.mapError(error)
            } catch let error as AuthClientError {
                throw error
            } catch {
                throw AuthClientError.unknown
            }
        }
        
        @Sendable func autoLogin() async throws -> User {
            do {
                return try await authRepository.restoreSession()
            } catch {
                throw AuthClient.mapError(error)
            }
        }
        
        @Sendable func signOut() async throws -> Void {
            do {
                try await authRepository.logout()
                kakaoSDKHelper.logout()
            } catch {
                throw AuthClient.mapError(error)
            }
        }
        
        @Sendable func withdraw() async throws -> Void {
            do {
                try await authRepository.withdraw()
                kakaoSDKHelper.logout()
            } catch {
                throw AuthClient.mapError(error)
            }
        }
        
        @Sendable func updateProfile(_ nickname: String?, profileImage: Data?) async throws -> Void {
            var uploadedImageID: Int?
            if let profileImage {
                do {
                    let imageEntity = ImageUploadEntity(data: profileImage, format: .jpeg)
                    guard let id = try await imageUploadRepository.upload(items: [imageEntity], mediaType: .userProfile).first else { throw AuthClientError.serverError("프로필 이미지 업로드 실패") }
                    uploadedImageID = id
                } catch {
                    throw AuthClient.mapError(error)
                }
            }
            
            do {
                try await authRepository.updateProfile(nickname: nickname, profileImageID: uploadedImageID)
            } catch {
                throw AuthClient.mapError(error)
            }
        }
        
        @Sendable func handleKakaoOpenURL(_ url: URL) -> Void {
            Task { @MainActor in kakaoSDKHelper.handleOpenURL(url) }
        }
        
        return AuthClient(
            loginWithApple: loginWithApple,
            loginWithKakao: loginWithKakao,
            autoLogin: autoLogin,
            signOut: signOut,
            withdraw: withdraw,
            updateProfile: updateProfile,
            handleKakaoOpenURL: handleKakaoOpenURL
        )
    }()
}


// MARK: - AuthClient + Helpers

private extension AuthClient {
    static func mapError(_ error: Error) -> AuthClientError {
        if let repositoryError = error as? AuthRepositoryError {
            switch repositoryError {
            case .networkError(let networkError):
                switch networkError {
                case .networkFail: return .networkConnectionLost
                case .unauthorizedError: return .sessionExpired
                default: return .serverError(networkError.localizedDescription)
                }
            case .unauthorized, .userNotFound:
                return .sessionExpired
            case .unknown:
                return .unknown
            }
        }
        
        if let uploadError = error as? UploadError {
            switch uploadError {
            case .presignedUrlFailed:
                return .serverError("이미지 업로드 정보를 받아올 수 없음.")
            case .uploadFailed:
                return .networkConnectionLost
            }
        }
        
        return .unknown
    }
}


// MARK: - AuthClient + Nested Types

private extension AuthClient {
    final class KakaoSDKHelper {
        typealias IdentityToken = String
        
        private let kakaoAPI = UserApi.shared
        
        private func handleResponse(_ oAuthToken: OAuthToken?, error: Error?, _ continuation: CheckedContinuation<Result<IdentityToken, Error>, Never>) {
            if let error = error {
                Logger.domain.error("Kakao Login Failed: \(error.localizedDescription)")
                continuation.resume(returning: .failure(error))
            } else if let idToken = oAuthToken?.idToken {
                Logger.domain.debug("Kakao Login Success")
                continuation.resume(returning: .success(idToken))
            } else {
                let tokenError = AuthClientError.invalidClientToken
                Logger.domain.error("Kakao Login Failed: Identity token is nil")
                continuation.resume(returning: .failure(tokenError))
            }
        }
        
        private func mapKakaoError(_ error: SdkError) -> AuthClientError {
            switch error {
            case let .ClientFailed(reason, info):
                if case .Cancelled = reason { return .cancelled }
                return .serverError("KAkao Auth Error: \(reason)-\(info ?? "")")
            case let .ApiFailed(reason, info):
                return .serverError("Kakao Auth Error: \(reason)-\(info?.msg ?? "")")
            case let .AuthFailed(reason, info):
                return .serverError("Kakao Auth Error: \(reason)-\(info?.errorDescription ?? "")")
            default: return .unknown
            }
        }
        
        @MainActor
        func login() async throws(AuthClientError) -> IdentityToken {
            let result: Result<IdentityToken, Error> = await withCheckedContinuation { continuation in
                if UserApi.isKakaoTalkLoginAvailable() {
                    kakaoAPI.loginWithKakaoTalk { self.handleResponse($0, error: $1, continuation) }
                } else {
                    kakaoAPI.loginWithKakaoAccount { self.handleResponse($0, error: $1, continuation) }
                }
            }
            
            switch result {
            case .success(let idToken):
                return idToken
            case .failure(let error):
                if let sdkError = error as? SdkError {
                    throw mapKakaoError(sdkError)
                } else if let authError = error as? AuthClientError {
                    throw authError
                } else {
                    throw AuthClientError.unknown
                }
            }
        }
        
        func logout() {
            kakaoAPI.logout { error in
                guard let error = error else { return }
                Logger.domain.error("Kakao Logout Failed: \(error.localizedDescription)")
            }
        }
        
        @MainActor
        func handleOpenURL(_ url: URL) {
            guard AuthApi.isKakaoTalkLoginUrl(url) else { return }
            _ = AuthController.handleOpenUrl(url: url)
        }
    }
}

// MARK: - Dependency Registration
extension DependencyValues {
    public var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
