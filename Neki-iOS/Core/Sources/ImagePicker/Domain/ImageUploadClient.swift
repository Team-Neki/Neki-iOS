//
//  ImageUploadClient.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import ComposableArchitecture
import Foundation

public struct ImageUploadClient {
    public var upload: @Sendable (_ data: [ImageUploadEntity], _ mediaType: ImageMediaType) async throws -> [Int]
}

extension ImageUploadClient: DependencyKey {
    public static let liveValue: ImageUploadClient = {
        return ImageUploadClient(
            upload: { items, mediaType in
                @Dependency(\.imageUploadRepository) var repository

                return try await repository.upload(items: items, mediaType: mediaType)
            }
        )
    }()
}

extension DependencyValues {
    public var imageUploadClient: ImageUploadClient {
        get { self[ImageUploadClient.self] }
        set { self[ImageUploadClient.self] = newValue }
    }
}
