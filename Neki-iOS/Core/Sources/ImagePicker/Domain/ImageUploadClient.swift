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
                return try await withThrowingTaskGroup(of: [Int].self) { group in
                    var uploadedMediaIDs: [Int] = []
                    let maxConcurrentTasks = 3
                    var urlIterator = fileURLs.makeIterator()
                    
                    for _ in 0..<maxConcurrentTasks {
                        guard let url = urlIterator.next() else { break }
                        group.addTask {
                            let data = try Data(contentsOf: url)
                            let entity = ImageUploadEntity(data: data, format: data.detectedImageFormat)
                            return try await repository.upload(items: [entity], mediaType: mediaType)
                        }
                    }
                    
                    for try await resultIDs in group {
                        uploadedMediaIDs.append(contentsOf: resultIDs)
                        
                        guard let nextURL = urlIterator.next() else { continue }
                        group.addTask {
                            let data = try Data(contentsOf: nextURL)
                            let entity = ImageUploadEntity(data: data, format: data.detectedImageFormat)
                            return try await repository.upload(items: [entity], mediaType: mediaType)
                        }
                    }
                    
                    return uploadedMediaIDs
                }
            },
            
            convert: { items in
                await withTaskGroup(of: ImageUploadEntity?.self) { group in
                    for item in items {
                        group.addTask {
                            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
                            return ImageUploadEntity(data: data, format: data.detectedImageFormat)
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
