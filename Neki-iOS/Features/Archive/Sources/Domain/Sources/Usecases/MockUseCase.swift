//
//  MockUseCase.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

public protocol MockUseCase {
    func execute(page: Int, category: String) async throws -> MockEntity
}

public final class DefaultMockUseCase: MockUseCase {
    
    private let repository: MockRepository
    
    public init(repository: MockRepository) {
        self.repository = repository
    }
    
    public func execute(page: Int, category: String) async throws -> MockEntity {
        return try await repository.fetchMockList(page: page, category: category)
    }
}
