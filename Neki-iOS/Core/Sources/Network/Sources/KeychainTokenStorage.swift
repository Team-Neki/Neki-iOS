//
//  KeychainTokenStorage.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation
import Security
import os

final actor KeychainTokenStorage {
    private var generation = UUID()
    private var revision = UUID()
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

    func makeQuery() -> [String: Any] {
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
    
    func create(_ tokens: AuthTokens, in query: [String: Any]) throws(TokenStorageError) {
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
    
    func read(_ query: [String: Any]) throws(TokenStorageError) -> CFTypeRef? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var dataTypeRef: CFTypeRef? = nil
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        try checkStatus(status, which: #function)
        return dataTypeRef
    }
    
    func update(_ tokens: AuthTokens, in query: [String: Any]) throws(TokenStorageError) {
        do {
            let data = try encoder.encode(tokens)
            let queryToUpdate: [String: Any] = [kSecValueData as String: data]
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
    
    func delete(_ query: [String: Any]) throws(TokenStorageError) {
        let status = SecItemDelete(query as CFDictionary)
        guard status != errSecItemNotFound else { return }
        try checkStatus(status, which: #function)
    }
}


// MARK: - KeychainTokenStorage + TokenStorage

extension KeychainTokenStorage: TokenStorage {
    var credentialGeneration: UUID { generation }

    func store(_ tokens: AuthTokens) async throws(TokenStorageError) {
        try storeTokens(tokens)
        generation = UUID()
        revision = UUID()
    }
    
    func fetch() async throws(TokenStorageError) -> AuthTokens {
        guard let tokens = try storedTokens() else { throw .notFound }
        return tokens
    }

    func snapshot() async throws(TokenStorageError) -> TokenStorageSnapshot {
        TokenStorageSnapshot(tokens: try storedTokens(), generation: generation, revision: revision)
    }
    
    func delete() async throws(TokenStorageError) {
        try delete(makeQuery())
        generation = UUID()
        revision = UUID()
    }

    func delete(ifMatchingGeneration generation: UUID) async throws(TokenStorageError) -> Bool {
        guard self.generation == generation else { return false }
        try delete(makeQuery())
        self.generation = UUID()
        revision = UUID()
        return true
    }

    func store(_ tokens: AuthTokens, replacing revision: UUID) async throws(TokenStorageError) -> TokenStorageSnapshot? {
        guard self.revision == revision else { return nil }
        try storeTokens(tokens)
        self.revision = UUID()
        return TokenStorageSnapshot(tokens: tokens, generation: generation, revision: self.revision)
    }

    func delete(ifMatching revision: UUID) async throws(TokenStorageError) -> Bool {
        guard self.revision == revision else { return false }
        try delete(makeQuery())
        generation = UUID()
        self.revision = UUID()
        return true
    }
}
