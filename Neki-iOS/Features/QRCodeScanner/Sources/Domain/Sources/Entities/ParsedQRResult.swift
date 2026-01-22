//
//  ParsedQRResult.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation

public struct ParsedQRResult: Equatable, Sendable {
    public let brand: PhotoBoothBrand
    public let originalImage: Data
    
    public init(brand: PhotoBoothBrand, originalImage: Data) {
        self.brand = brand
        self.originalImage = originalImage
    }
}
