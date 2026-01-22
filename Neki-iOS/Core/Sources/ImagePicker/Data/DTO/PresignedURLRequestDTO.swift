//
//  PresignedURLDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import Foundation

public enum PresignedURLDTO {
    public struct Request: Encodable {
        public let filename: String
        public let contentType: String
        public let mediaType: String
    }
    
    public typealias Response = BaseResponseDTO<ResponseData>
      
    public struct ResponseData: Decodable {
        public let mediaID: Int
        public let uploadURL, method, expiresIn, contentType: String

        enum CodingKeys: String, CodingKey {
            case mediaID = "mediaId"
            case uploadURL = "uploadUrl"
            case method, expiresIn, contentType
        }
    }
}
