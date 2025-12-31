//
//  MockResponseDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
//import Core

typealias MockResponseDTO = BaseResponseDTO<MockResponseData>

struct MockResponseData: Decodable {
    let mockResponseList: [String]
}

extension MockResponseDTO {
    func toEntity() -> MockEntity {
        return MockEntity(
            titles: self.data?.mockResponseList ?? []
        )
    }
}
