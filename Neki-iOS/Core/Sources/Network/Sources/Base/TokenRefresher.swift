//
//  TokenRefresher.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

public protocol TokenRefresher: Sendable {
    func refresh(provider: NetworkProvider, tokens: AuthTokens) async throws -> AuthTokens
}
