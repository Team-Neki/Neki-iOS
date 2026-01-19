//
//  NetworkProvider.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

public protocol NetworkProvider {
    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData>
    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T>
}
