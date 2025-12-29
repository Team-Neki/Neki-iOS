//
//  MockEntity.swift
//  Neki-iOS
//
//  Created by OneTen on 12/30/25.
//

import Foundation

public struct MockEntity: Equatable, Identifiable {
    public let id: Int
    public let title: String
    public let content: String
    public let imageURL: String?
    public let createdAt: Date
    
    public init(
        id: Int,
        title: String,
        content: String,
        imageURL: String?,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.imageURL = imageURL
        self.createdAt = createdAt
    }
}
