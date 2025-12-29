//
//  BaseResponseDTO.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

struct BaseResponseDTO<T: Decodable>: Decodable {
    let status: Int
    let message: String
    let data: T?
}
