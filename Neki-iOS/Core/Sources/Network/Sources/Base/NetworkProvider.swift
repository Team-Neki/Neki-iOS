//
//  NetworkProvider.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
import ComposableArchitecture

public protocol NetworkProvider: Sendable {
    func requestVoid(endpoint: Endpoint) async throws -> Void
    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData>
    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T>
}

private enum NetworkProviderKey: DependencyKey {
    static let liveValue: NetworkProvider = {
        let tokenRefresher = AuthTokenRefresher()
        let networkProvider = DefaultNetworkProvider(refresher: tokenRefresher)
        return networkProvider
    }()
}

public extension DependencyValues {
    var networkProvider: NetworkProvider {
        get { self[NetworkProviderKey.self] }
        set { self[NetworkProviderKey.self] = newValue }
    }
}
