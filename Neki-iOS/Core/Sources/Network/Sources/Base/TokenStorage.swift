//
//  TokenStorage.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

protocol TokenStorage {
    /// 로그인/삭제 시 변경되며, 같은 세션의 토큰 재발급에서는 유지되는 식별자입니다.
    var credentialGeneration: UUID { get }
    
    func store(_ tokens: AuthTokens) throws(TokenStorageError)
    func fetch() throws(TokenStorageError) -> AuthTokens
    func snapshot() throws(TokenStorageError) -> TokenStorageSnapshot
    func delete() throws(TokenStorageError)
    /// 자격증명 세대가 요청 시점과 같을 때만 현재 세션을 삭제합니다.
    func delete(ifMatchingGeneration generation: UUID) throws(TokenStorageError) -> Bool
    /// 저장 버전이 요청 시점과 같을 때만 재발급 결과를 저장합니다.
    func store(_ tokens: AuthTokens, replacing revision: UUID) throws(TokenStorageError) -> TokenStorageSnapshot?
    /// 저장 버전이 일치할 때만 삭제합니다. 토큰이 없는 상태에서도 중복 처리를 막도록 버전을 변경합니다.
    func delete(ifMatching revision: UUID) throws(TokenStorageError) -> Bool
}

public enum TokenStorageError: Error {
    case unknown
    case notFound
    case conversionFailed
}
