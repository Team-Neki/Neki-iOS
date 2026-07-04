//
//  ArchiveMediaClient.swift
//  Neki-iOS
//
//  Created by Codex on 7/3/26.
//

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct ArchiveMediaClient {
    var fetchOriginalImageData: @Sendable (_ url: URL) async throws -> Data
    var shareInstagramStory: @Sendable (_ imageData: Data) async throws -> Bool
}

extension ArchiveMediaClient: DependencyKey {
    static let liveValue: ArchiveMediaClient = {
        @Dependency(\.archiveMediaRepository) var repository
        return ArchiveMediaClient(
            fetchOriginalImageData: { try await repository.fetchOriginalImageData(from: $0) },
            shareInstagramStory: { try await repository.shareInstagramStory(imageData: $0) }
        )
    }()
}

extension DependencyValues {
    var archiveMediaClient: ArchiveMediaClient {
        get { self[ArchiveMediaClient.self] }
        set { self[ArchiveMediaClient.self] = newValue }
    }
}
