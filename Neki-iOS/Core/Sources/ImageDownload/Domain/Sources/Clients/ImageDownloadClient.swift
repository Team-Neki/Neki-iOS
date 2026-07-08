//
//  ImageDownloadClient.swift
//  Neki-iOS
//
//  Created by OneTen on 2/2/26.
//

import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct ImageDownloadClient {
    public var downloadImages: (_ urls: [URL]) async throws -> Int
}

extension ImageDownloadClient: DependencyKey {
    public static let liveValue: ImageDownloadClient = {
        @Dependency(\.imageDownloadRepository) var repository

        return Self(
            downloadImages: { urls in
                try await repository.downloadImages(urls: urls)
            }
        )
    }()
}

public extension DependencyValues {
    var imageDownloadClient: ImageDownloadClient {
        get { self[ImageDownloadClient.self] }
        set { self[ImageDownloadClient.self] = newValue }
    }
}
