//
//  MockRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

public protocol MockRepository {
    func fetchMockList(page: Int, category: String) async throws -> MockEntity
}
