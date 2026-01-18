//
//  TokenStorage.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

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
