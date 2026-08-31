//
//  KeychainTokenStorage.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation
import Security
import os

final class KeychainTokenStorage: Sendable {
    private struct State: Sendable {
        var generation = UUID()
        var revision = UUID()
    }

    // 토큰의 비교/교체와 세대 변경을 같은 임계 구역에서 처리합니다. 내부에는 await가 없습니다.
    private let lock = OSAllocatedUnfairLock(initialState: State())
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let service: String
    private let account: String
    
    init(
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        service: String = Bundle.main.bundleIdentifier ?? "com.neki.app",
        account: String = "com.neki.tokenStorage"
    ) {
        self.encoder = encoder
        self.decoder = decoder
        self.service = service
        self.account = account
    }
}


// MARK: - KeychainTokenStorage + Helper Methods

private extension KeychainTokenStorage {
    func withLock<Value: Sendable>(_ operation: @Sendable (inout State) throws(TokenStorageError) -> Value) throws(TokenStorageError) -> Value {
        let result: Result<Value, TokenStorageError> = lock.withLock { state in
            do { return .success(try operation(&state)) }
            catch { return .failure(error) }
        }
        return try result.get()
    }

    func storedTokens() throws(TokenStorageError) -> AuthTokens? {
        do { return try convert(read(makeQuery())) }
        catch .notFound { return nil }
        catch { throw error }
    }

    func storeTokens(_ tokens: AuthTokens) throws(TokenStorageError) {
        let query = makeQuery()
        do { try update(tokens, in: query) }
        catch .notFound { try create(tokens, in: query) }
        catch { throw error }
    }

    func makeQuery() -> Query {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
    
    func checkStatus(_ status: OSStatus, which function: String) throws(TokenStorageError) {
        guard status != noErr else { return }
        let errorMessage = SecCopyErrorMessageString(status, nil) as? String ?? "\(TokenStorageError.unknown)"
        Logger.data.debug("토큰 저장소 쿼리 실행 중 에러 발생 - \(function): \(errorMessage)")
        throw status == errSecItemNotFound ? .notFound : .unknown
    }
    
    func convert(_ ref: CFTypeRef?) throws(TokenStorageError) -> AuthTokens {
        guard let ref = ref else { throw .notFound }
        guard let data = ref as? Data, let tokens = try? decoder.decode(AuthTokens.self, from: data) else { throw .conversionFailed }
        return tokens
    }
    
    func create(_ tokens: AuthTokens, in query: Query) throws(TokenStorageError) {
        do {
            let data = try encoder.encode(tokens)
            var query = query
            query[kSecValueData as String] = data
            
            let status = SecItemAdd(query as CFDictionary, nil)
            try checkStatus(status, which: #function)
        } catch is EncodingError {
            throw .conversionFailed
        } catch let error as TokenStorageError {
            throw error
        } catch {
            throw .unknown
        }
    }
    
    func read(_ query: Query) throws(TokenStorageError) -> CFTypeRef? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var dataTypeRef: CFTypeRef? = nil
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        try checkStatus(status, which: #function)
        return dataTypeRef
    }
    
    func update(_ tokens: AuthTokens, in query: Query) throws(TokenStorageError) {
        do {
            let data = try encoder.encode(tokens)
            let queryToUpdate: Query = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, queryToUpdate as CFDictionary)
            try checkStatus(status, which: #function)
        } catch is EncodingError {
            throw .conversionFailed
        } catch let error as TokenStorageError {
            throw error
        } catch {
            throw .unknown
        }
    }
    
    func delete(_ query: Query) throws(TokenStorageError) {
        let status = SecItemDelete(query as CFDictionary)
        guard status != errSecItemNotFound else { return }
        try checkStatus(status, which: #function)
    }
}


// MARK: - KeychainTokenStorage + TokenStorage

extension KeychainTokenStorage: TokenStorage {
    var credentialGeneration: UUID { lock.withLock { $0.generation } }

    func store(_ tokens: AuthTokens) throws(TokenStorageError) {
        try withLock { (state: inout State) throws(TokenStorageError) in
            try storeTokens(tokens)
            state = State()
        }
    }
    
    func fetch() throws(TokenStorageError) -> AuthTokens {
        try withLock { (_: inout State) throws(TokenStorageError) in
            guard let tokens = try storedTokens() else { throw .notFound }
            return tokens
        }
    }

    func snapshot() throws(TokenStorageError) -> TokenStorageSnapshot {
        try withLock { (state: inout State) throws(TokenStorageError) in
            TokenStorageSnapshot(tokens: try storedTokens(), generation: state.generation, revision: state.revision)
        }
    }
    
    func delete() throws(TokenStorageError) {
        try withLock { (state: inout State) throws(TokenStorageError) in
            try delete(makeQuery())
            state = State()
        }
    }

    func store(_ tokens: AuthTokens, replacing revision: UUID) throws(TokenStorageError) -> TokenStorageSnapshot? {
        try withLock { (state: inout State) throws(TokenStorageError) in
            guard state.revision == revision else { return nil }
            try storeTokens(tokens)
            state.revision = UUID()
            return TokenStorageSnapshot(tokens: tokens, generation: state.generation, revision: state.revision)
        }
    }

    func delete(ifMatching revision: UUID) throws(TokenStorageError) -> Bool {
        try withLock { (state: inout State) throws(TokenStorageError) in
            guard state.revision == revision else { return false }
            try delete(makeQuery())
            state = State()
            return true
        }
    }
}
