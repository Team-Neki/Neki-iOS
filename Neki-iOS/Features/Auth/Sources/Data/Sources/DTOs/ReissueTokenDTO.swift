//
//  ReissueTokenDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/13/26.
//

import Foundation

enum ReissueTokenDTO {
    struct Request: Encodable {
        let refreshToken: String
    }
    
    typealias Response = TokenPair
}
