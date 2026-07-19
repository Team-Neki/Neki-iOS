//
//  AuraPicShootDataDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/19/26.
//

import Foundation

enum AuraPicShootDataDTO {
    struct Response: Decodable {
        let result: Bool
        let datas: [Item]?
    }

    struct Item: Decodable {
        let urlFolderPath: String
    }
}
