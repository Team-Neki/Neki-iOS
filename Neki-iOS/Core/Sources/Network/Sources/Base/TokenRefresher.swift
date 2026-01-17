//
//  TokenRefresher.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

public protocol TokenRefresher: Sendable {
    var destination: Endpoint { get }
    
    func refresh(provider: NetworkProvider) async throws(NetworkError) -> AuthTokens
}
