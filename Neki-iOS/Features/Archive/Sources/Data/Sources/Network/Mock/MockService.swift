//
//  MockService.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

protocol MockServiceProtocol {
    func fetchMockData(page: Int, category: String) async throws -> MockResponseDTO
}

final class MockService: MockServiceProtocol {
    
    private let provider = DefaultNetworkProvider.shared
    
    func fetchMockData(page: Int, category: String) async throws -> MockResponseDTO {
        return try await provider.request(endpoint: MockAPI.getTest(page: page, category: category))
    }
}
