//
//  PhotoBoothBrand.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation

/// 포토부스 브랜드의 종류입니다.
public struct PhotoBoothBrand: Identifiable, Sendable, Equatable, Hashable {
    public let id: Int
    public let name: String
    public let englishName: String
    public let imageURL: URL?
    
    public init(id: Int, name: String, englishName: String, imageURL: URL?) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.imageURL = imageURL
    }
}
