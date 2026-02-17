//
//  FetchAppVersionDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/17/26.
//

import Foundation

enum FetchAppVersionDTO {
    struct Response: Decodable {
        let minimumVersion: String
        let currentVersion: String
        
        enum CodingKeys: String, CodingKey {
            case minimumVersion = "minVersion"
            case currentVersion
        }
    }
}
