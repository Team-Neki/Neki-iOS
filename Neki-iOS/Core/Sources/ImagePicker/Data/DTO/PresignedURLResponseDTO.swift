//
//  PresignedURLResponseDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import Foundation

public typealias PresignedURLResponseDTO = BaseResponseDTO<PresignedURLResponseData>

public struct PresignedURLResponseData: Decodable {
    public let mediaID: Int
    public let uploadURL: String
    public let method: String
    public let expiresIn: Double
    public let contentType: String
    
    enum CodingKeys: String, CodingKey {
        case mediaID = "mediaId"
        case uploadURL = "uploadUrl"
        case method, expiresIn, contentType
    }
}
