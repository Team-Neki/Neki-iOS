//
//  ImageUploadEntity.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import Foundation

public struct ImageUploadEntity: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let data: Data            // 업로드용 Raw Data
    public let fileExtension: String // "jpg", "png"
    public let contentType: String      // "image/jpeg", "image/png"
    
    public init(
        id: UUID = UUID(),
        data: Data,
        fileExtension: String,
        contentType: String
    ) {
        self.id = id
        self.data = data
        self.fileExtension = fileExtension
        self.contentType = contentType
    }
}

public enum ImageMediaType: String, Encodable, Equatable, Sendable {
    case userProfile = "USER_PROFILE"
    case photoBooth = "PHOTO_BOOTH"
    case attachment = "ATTACHMENT"
    case temp = "TEMP"
}
