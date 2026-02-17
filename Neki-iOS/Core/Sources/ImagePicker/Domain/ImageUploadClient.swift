//
//  ImageUploadClient.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import ComposableArchitecture
import SwiftUI
import PhotosUI

public struct ImageUploadClient {
    public var upload: @Sendable (_ data: [ImageUploadEntity], _ mediaType: ImageMediaType) async throws -> [Int]
    public var convert: @Sendable (_ items: [PhotosPickerItem]) async -> [ImageUploadEntity]
}

extension ImageUploadClient: DependencyKey {
    public static let liveValue: ImageUploadClient = {
        @Dependency(\.imageUploadRepository) var repository
        
        return ImageUploadClient(
            upload: { items, mediaType in
                return try await repository.upload(items: items, mediaType: mediaType)
            },
            convert: { items in
                await withTaskGroup(of: ImageUploadEntity?.self) { group in
                    for item in items {
                        group.addTask {
                            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
                            let format = data.detectedImageFormat
                            return ImageUploadEntity(data: data, format: format)
                        }
                    }
                    
                    var results: [ImageUploadEntity] = []
                    for await result in group {
                        guard let result else { continue }
                        results.append(result)
                    }
                    
                    return results
                }
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
