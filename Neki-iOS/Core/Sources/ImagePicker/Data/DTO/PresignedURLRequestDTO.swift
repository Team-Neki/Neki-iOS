//
//  PresignedURLRequestDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import Foundation

public struct PresignedURLRequestDTO: Encodable {
    public let filename: String
    public let contentType: String
    public let mediaType: String
}
