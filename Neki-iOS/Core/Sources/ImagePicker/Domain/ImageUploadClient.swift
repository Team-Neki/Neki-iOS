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
    public var uploadConcurrentlyFromURLs: @Sendable (_ fileURLs: [URL], _ mediaType: ImageMediaType) async throws -> [Int]
    public var convert: @Sendable (_ items: [PhotosPickerItem]) async -> [ImageUploadEntity]
}

extension ImageUploadClient: DependencyKey {
    public static let liveValue: ImageUploadClient = {
        @Dependency(\.imageUploadRepository) var repository
        
        return ImageUploadClient(
            upload: { items, mediaType in
                return try await repository.upload(items: items, mediaType: mediaType)
            },
            
            uploadConcurrentlyFromURLs: { fileURLs, mediaType in
                var uploadedMediaIDs: [Int] = []
                let chunkSize: Int = 3
                let chunks = stride(from: 0, to: fileURLs.count, by: chunkSize).map { Array(fileURLs[$0..<min($0 + chunkSize, fileURLs.count)]) }
                
                for chunk in chunks {
                    var entities: [ImageUploadEntity] = []
                    for url in chunk {
                        let data = try Data(contentsOf: url)
                        let dimensions = data.imageDimensions
                        
                        entities.append(
                            ImageUploadEntity(
                                data: data,
                                format: data.detectedImageFormat,
                                width: dimensions?.width,
                                height: dimensions?.height,
                                size: data.count
                            )
                        )
                    }
                    
                    let resultIDs = try await repository.upload(items: entities, mediaType: mediaType)
                    uploadedMediaIDs.append(contentsOf: resultIDs)
                }
                return uploadedMediaIDs
            },
            
            convert: { items in
                await withTaskGroup(of: ImageUploadEntity?.self) { group in
                    for item in items {
                        group.addTask {
                            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
                            let dimensions = data.imageDimensions
                            
                            return ImageUploadEntity(
                                data: data,
                                format: data.detectedImageFormat,
                                width: dimensions?.width,
                                height: dimensions?.height,
                                size: data.count
                            )
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
