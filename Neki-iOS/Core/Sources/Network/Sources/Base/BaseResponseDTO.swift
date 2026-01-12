//
//  BaseResponseDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

public struct BaseResponseDTO<T: Decodable>: Decodable {
    let status: Int
    let message: String
    let isSuccess: Bool
    let data: T?
    
    enum CodingKeys: String, CodingKey {
        case message, data
        case status = "resultCode"
        case isSuccess = "success"
    }
}

public struct EmptyData: Decodable {}

public struct BaseFailedResponseDTO: Decodable {
    let status: Int
    let message: String
    let timestamp: String
}
