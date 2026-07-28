//
//  UserInfoDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation

enum UserInfoDTO {
    struct Response: Decodable {
        let id: Int
        let nickname: String
        let email: String?
        let profileImageURLString: String?
        let providerType: String
        let agreedTerms: Bool
        let marketingTerm: Bool
        let pushNotificationAgreed: Bool
        
        enum CodingKeys: String, CodingKey {
            case id = "userId"
            case nickname = "name"
            case profileImageURLString = "profileImageUrl"
            case agreedTerms = "agreeTerms"
            case pushNotificationAgreed = "pushAgreed"
            case email, providerType, marketingTerm
        }
    }
}
