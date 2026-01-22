//
//  NetworkProvider.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
import ComposableArchitecture

public protocol NetworkProvider {
    func requestVoid(endpoint: Endpoint) async throws -> Void
    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData>
    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T>
}

private enum NetworkProviderKey: DependencyKey {
    static let liveValue: NetworkProvider = {
        let tokenStorage = KeychainTokenStorage(
            encoder: JSONEncoder(),
            decoder: JSONDecoder()
        )
        
        let provider = DefaultNetworkProvider(
            tokenStorage: tokenStorage
        )
        
        return provider
    }()
}

public extension DependencyValues {
    var networkProvider: NetworkProvider {
        get { self[NetworkProviderKey.self] }
        set { self[NetworkProviderKey.self] = newValue }
    }
}
