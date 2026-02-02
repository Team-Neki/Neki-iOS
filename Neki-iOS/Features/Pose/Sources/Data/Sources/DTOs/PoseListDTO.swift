//
//  PoseListDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation

enum PoseListDTO {
    struct Response: Decodable {
        let items: [PoseDTO]
        let hasNext: Bool
    }
}
