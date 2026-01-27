//
//  PresignedURLResponseDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import Foundation

public typealias PresignedURLResponseDTO = BaseResponseDTO<PresignedURLResponseData>

public struct PresignedURLResponseData: Decodable {
    public let method: String
    public let expiresIn: String
    public let items: [PresignedURLResponseItem]
}

public struct PresignedURLResponseItem: Decodable {
    public let mediaID: Int
    public let uploadTicket: String
    public let contentType: String
    
    enum CodingKeys: String, CodingKey {
        case mediaID = "mediaId"
        case uploadTicket
        case contentType
    }
}
