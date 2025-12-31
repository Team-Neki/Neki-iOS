//
//  MockService.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

protocol MockService {
    func fetchMockData(page: Int, category: String) async throws -> MockResponseDTO
}

final class DefaultMockService: MockService {
    
    private let provider: NetworkProvider
    
    init(provider: NetworkProvider) {
        self.provider = provider
    }
    
    func fetchMockData(page: Int, category: String) async throws -> MockResponseDTO {
        return try await provider.request(endpoint: MockAPI.getTest(page: page, category: category))
    }
}
