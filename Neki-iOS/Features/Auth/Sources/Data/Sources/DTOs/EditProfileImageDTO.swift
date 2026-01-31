//
//  EditProfileImageDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/31/26.
//

import Foundation

enum EditProfileImageDTO {
    struct Request: Encodable {
        let imageID: Int?
        
        enum CodingKeys: String, CodingKey {
            case imageID = "mediaId"
        }
    }
    
    typealias Response = EmptyData
}
