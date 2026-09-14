//
//  NetworkProvider.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
import Dependencies

public protocol NetworkProvider: Sendable {
    func requestVoid(endpoint: Endpoint) async throws -> Void
    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData>
    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T>
}


// MARK: - NetworkProvider + DependencyKey

private enum NetworkProviderKey: DependencyKey {
    static let liveValue: any NetworkProvider = {
        @Dependency(\.self) var dependencies
        let broker = dependencies[NetworkCredentialBrokerKey.self]
        // 수신자는 실패 발생 시 조회합니다. Provider 생성 중 AuthRepository를 생성하지 않습니다.
        return DefaultNetworkProvider(credentialBroker: broker) { failure, isCurrent in
            @Dependency(\.authRepository) var authRepository
            let failureHandler: any AuthCredentialFailureHandling = authRepository
            let reason: AuthCredentialFailure.Reason
            switch failure.reason {
            case .credentialsUnavailable: reason = .missingCredentials
            case .unauthorized: reason = .rejectedCredentials
            }
            await failureHandler.reportCredentialFailure(
                .init(generation: failure.credentialGeneration, reason: reason),
                isCurrent: isCurrent
            )
        }
    }()
}

private enum NetworkCredentialBrokerKey: DependencyKey {
    static let liveValue = DefaultNetworkCredentialBroker()
}


// MARK: - NetworkProvider + Accessor

extension DependencyValues {
    /// 진단에는 읽기 계약만 제공합니다. Broker 전체를 가져오는 접근자는 노출하지 않습니다.
    var authTokenDiagnosticsReader: any AuthTokenDiagnosticsReading {
        self[NetworkCredentialBrokerKey.self]
    }

    var networkProvider: any NetworkProvider {
        get { self[NetworkProviderKey.self] }
        set { self[NetworkProviderKey.self] = newValue }
    }
}
