//
//  DefaultMockRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
// import ArchiveDomain

public final class DefaultMockRepository: MockRepository {
    
    private let service: MockService
    
    init(service: MockService) {
        self.service = service
    }
    
    public func fetchMockList(page: Int, category: String) async throws -> MockEntity {
        let result = try await service.fetchMockData(page: page, category: category)
        
        return result.toEntity()
    }
}
