//
//  ImageUploadEntity.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import Foundation

public struct ImageUploadEntity: Identifiable, Sendable {
    public let id: UUID
    public let data: Data
    public let format: ImageFileFormat
    
    public let width: Int?
    public let height: Int?
    public let size: Int?
    
    public var contentType: String { format.contentType }
    public var fileExtension: String { format.fileExtension }
    
    public init(
        id: UUID = UUID(),
        data: Data,
        format: ImageFileFormat,
        width: Int? = nil,
        height: Int? = nil,
        size: Int? = nil
    ) {
        self.id = id
        self.data = data
        self.format = format
        self.width = width
        self.height = height
        self.size = size
    }
}

public enum ImageFileFormat: Sendable {
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
