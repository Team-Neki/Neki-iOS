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
    var allRequiredTermsAgreed: Bool
    var marketingTermAgreed: Bool
    var pushNotificationAgreed: Bool

    init(
        id: Int,
        nickname: String,
        email: String?,
        profileImageURL: URL?,
        providerType: ProviderType,
        allRequiredTermsAgreed: Bool,
        marketingTermAgreed: Bool = false,
        pushNotificationAgreed: Bool = false
    ) {
        self.id = id
        self.nickname = nickname
        self.email = email
        self.profileImageURL = profileImageURL
        self.providerType = providerType
        self.allRequiredTermsAgreed = allRequiredTermsAgreed
        self.marketingTermAgreed = marketingTermAgreed
        self.pushNotificationAgreed = pushNotificationAgreed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case email
        case profileImageURL
        case providerType
        case allRequiredTermsAgreed
        case marketingTermAgreed
        case pushNotificationAgreed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        nickname = try container.decode(String.self, forKey: .nickname)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        profileImageURL = try container.decodeIfPresent(URL.self, forKey: .profileImageURL)
        providerType = try container.decode(ProviderType.self, forKey: .providerType)
        allRequiredTermsAgreed = try container.decode(Bool.self, forKey: .allRequiredTermsAgreed)
        marketingTermAgreed = try container.decodeIfPresent(Bool.self, forKey: .marketingTermAgreed) ?? false
        pushNotificationAgreed = try container.decodeIfPresent(Bool.self, forKey: .pushNotificationAgreed) ?? false
    }
}

extension User {
    static var dummy: Self {
        User(
            id: -1,
            nickname: "-",
            email: nil,
            profileImageURL: nil,
            providerType: .local,
            allRequiredTermsAgreed: true
        )
    }
}
