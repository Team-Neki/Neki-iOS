//
//  MockUseCase.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

public protocol MockUseCase {
    func executeFetch() async throws -> [MockEntity]
}
