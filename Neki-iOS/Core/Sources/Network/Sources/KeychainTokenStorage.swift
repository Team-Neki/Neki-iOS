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
        try checkStatus(status, which: #function)
    }
}


// MARK: - KeychainTokenStorage + TokenStorage

extension KeychainTokenStorage: TokenStorage {
    func store(_ tokens: AuthTokens) throws(TokenStorageError) {
        let query = makeQuery()
        
        do {
            guard let _ = try read(query) else { return }
            try update(tokens, in: query)
        } catch TokenStorageError.notFound {
            try create(tokens, in: query)
        }
    }
    
    func fetch() throws(TokenStorageError) -> AuthTokens {
        let query = makeQuery()
        let reference = try read(query)
        let data = try convert(reference)
        return data
    }
    
    func delete() throws(TokenStorageError) {
        let query = makeQuery()
        try delete(query)
    }
}
