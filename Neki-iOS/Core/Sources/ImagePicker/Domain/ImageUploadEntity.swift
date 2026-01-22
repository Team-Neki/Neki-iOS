//
//  ImageUploadEntity.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import Foundation

public struct ImageUploadEntity: Identifiable {
    public let id: UUID
    public let data: Data
    public let format: ImageFileFormat
    
    public var contentType: String { format.contentType }
    public var fileExtension: String { format.fileExtension }
    
    public init(
        id: UUID = UUID(),
        data: Data,
        format: ImageFileFormat
    ) {
        self.id = id
        self.data = data
        self.format = format
    }
}

public enum ImageFileFormat {
    case jpeg
    case png
    case webp
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .webp: return "webp"
        }
    }
    
    var contentType: String {
        switch self {
        case .jpeg: return "image/jpeg"
        case .png: return "image/png"
        case .webp: return "image/webp"
        }
    }
}

public enum ImageMediaType: String, Encodable, Equatable, Sendable {
    case userProfile = "USER_PROFILE"
    case photoBooth = "PHOTO_BOOTH"
    case attachment = "ATTACHMENT"
    case temp = "TEMP"
}
