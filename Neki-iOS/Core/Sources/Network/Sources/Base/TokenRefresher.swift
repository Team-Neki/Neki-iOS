//
//  TokenRefresher.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

public protocol TokenRefresher: Sendable {
    // TODO: destination 요구
//    var destination: Endpoint { get }
    
    // TODO: refresh 요구
//    func refresh(provider: NetworkProvider) async throws(NetworkError) -> AuthTokens
}
