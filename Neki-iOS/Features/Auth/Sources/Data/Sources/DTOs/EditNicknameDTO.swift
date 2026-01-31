//
//  EditNicknameDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/31/26.
//

import Foundation

enum EditNicknameDTO {
    struct Request: Encodable {
        let nickname: String
        
        enum CodingKeys: String, CodingKey {
            case nickname = "name"
        }
    }
    
    typealias Response = EmptyData
}
