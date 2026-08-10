//
//  UpdatePhotoBoothBrandOrderDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/22/26.
//

import Foundation

enum UpdatePhotoBoothBrandOrderDTO {
    struct Request: Encodable {
        let brandIDs: [Int]

        enum CodingKeys: String, CodingKey {
            case brandIDs = "brandIds"
        }
    }
}
