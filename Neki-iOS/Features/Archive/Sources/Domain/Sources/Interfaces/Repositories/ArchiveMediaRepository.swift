//
//  ArchiveMediaRepository.swift
//  Neki-iOS
//
//  Created by Codex on 7/3/26.
//

import Foundation

protocol ArchiveMediaRepository: Sendable {
    func fetchOriginalImageData(from url: URL) async throws -> Data
    @MainActor
    func shareInstagramStory(imageData: Data) async throws -> Bool
}
