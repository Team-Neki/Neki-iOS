//
//  TokenStorage.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation
import Dependencies
import DependenciesMacros

public protocol TokenStorage {
    typealias Query = [String: Any]
    
    func store(_ tokens: AuthTokens) throws(TokenStorageError)
    func fetch() throws(TokenStorageError) -> AuthTokens
    func delete() throws(TokenStorageError)
}

public enum TokenStorageError: Error {
    case unknown
    case notFound
    case conversionFailed
}

private enum TokenStorageKey: DependencyKey {
    static let liveValue: TokenStorage = KeychainTokenStorage(encoder: .init(), decoder: .init())
}

extension DependencyValues {
    var tokenStorage: TokenStorage {
        get { self[TokenStorageKey.self] }
        set { self[TokenStorageKey.self] = newValue }
    }
}
