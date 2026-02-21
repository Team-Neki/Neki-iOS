//
//  SocialLoginDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation

enum SocialLoginDTO {
    struct Request: Encodable {
        let idToken: String
        let platform: String?
    }
    
    typealias Response = TokenPair
}
