//
//  MockEntity.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

public struct MockEntity: Equatable, Identifiable {
    public let id: UUID
    public let titles: [String]
    
    public init(id: UUID = UUID(), titles: [String]) {
        self.id = id
        self.titles = titles
    }
}
