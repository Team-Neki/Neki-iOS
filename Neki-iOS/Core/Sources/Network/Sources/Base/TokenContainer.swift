//
//  TokenContainer.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/25/26.
//

import Foundation

public protocol TokenContainer {
    var accessToken: String { get }
    var refreshToken: String { get }
    
    func toEntity() -> AuthTokens
}
