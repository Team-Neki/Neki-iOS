//
//  PresignedURLRequestDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import Foundation

public struct PresignedURLRequestDTO: Encodable {
    public let items: [PresignedURLRequestData]
}

public struct PresignedURLRequestData: Encodable {
    public let filename: String
    public let contentType: String
    public let mediaType: String
    public let width, height, size: Int?
}
