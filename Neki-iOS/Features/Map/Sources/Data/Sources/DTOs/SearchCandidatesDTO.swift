//
//  SearchCandidatesDTO.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/31/26.
//

import Foundation

/// 지역 검색
enum SearchRegionsDTO {
    struct Response: Decodable {
        let items: [Item]
        let hasNext: Bool

        struct Item: Decodable {
            let code: String
            let name: String
            let fullName: String

            func toEntity() -> PhotoBoothSearchRegion {
                .init(code: code, name: name, fullName: fullName)
            }
        }
    }
}

/// 지하철역 검색
enum SearchStationsDTO {
    struct Response: Decodable {
        let items: [Item]
        let hasNext: Bool

        struct Item: Decodable {
            let name: String
            let lineName: String

            func toEntity() -> PhotoBoothSearchStation {
                .init(name: name, lineName: lineName)
            }
        }
    }
}

/// 부스 검색
enum SearchPhotoBoothsDTO {
    struct Response: Decodable {
        let items: [SearchPhotoBoothDTO]
        let hasNext: Bool
    }
}
