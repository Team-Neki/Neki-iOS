//
//  DefaultMockRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation
// import ArchiveDomain

public final class DefaultMockRepository: MockRepository {
    
    private let service: MockServiceProtocol
    
    init(service: MockServiceProtocol) {
        self.service = service
    }
    
    public func fetchMockList(page: Int, category: String) async throws -> MockEntity {
        let result = try await service.fetchMockData(page: page, category: category)
        
        return result.toEntity()
    }
}
