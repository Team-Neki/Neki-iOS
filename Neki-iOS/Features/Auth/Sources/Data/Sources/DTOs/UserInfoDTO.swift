//
//  UserInfoDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation

enum UserInfoDTO {
    struct Response: Decodable {
        let nickname: String
        let providerType: String
        
        enum CodingKeys: String, CodingKey {
            case providerType
            case nickname = "name"
        }
    }
}
