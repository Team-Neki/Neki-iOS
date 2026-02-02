//
//  User.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/12/26.
//

import Foundation

/// 사용자 정보
public struct User: Sendable, Equatable, Codable {
    let id: Int
    let nickname: String
    let email: String?
    let profileImageURL: URL?
    let providerType: ProviderType
}
