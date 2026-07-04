//
//  FileManagerSharedImageRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 3/20/26.
//

import Foundation
import Dependencies
import DependenciesMacros
import UniformTypeIdentifiers
import os

public struct FileManagerSharedImageRepository: @unchecked Sendable {
    private let fileManager: FileManager
    
    public init(fileManager: FileManager = .default) { self.fileManager = fileManager }
    
    private func sharedImageURLs(for appGroupID: String) throws -> [URL] {
        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return [] }
        let sharedDirectoryURL = groupURL.appendingPathComponent("SharedImages", conformingTo: .directory)
        
        guard fileManager.fileExists(atPath: sharedDirectoryURL.path()) else { return [] }
        return try fileManager.contentsOfDirectory(at: sharedDirectoryURL, includingPropertiesForKeys: nil)
    }
}


// MARK: - FileManagerSharedImageRepository + SharedImageRepository

extension FileManagerSharedImageRepository: SharedImageRepository {
    public func fetchSharedImageURLs(appGroupID: String) async throws -> [URL] {
        return try sharedImageURLs(for: appGroupID)
    }

    public func fetchSharedImages(appGroupID: String) async throws -> [ImageUploadEntity] {
        let fileURLs = try sharedImageURLs(for: appGroupID)
        return await withTaskGroup(of: (Int, ImageUploadEntity?).self) { group in
            var iterator = fileURLs.enumerated().makeIterator()
            let concurrencyLimit = min(4, fileURLs.count)

            for _ in 0..<concurrencyLimit {
                guard let (index, fileURL) = iterator.next() else { break }
                group.addTask { await Self.loadSharedImage(at: fileURL, index: index) }
            }

            var results: [(Int, ImageUploadEntity)] = []
            while let (index, entity) = await group.next() {
                if let entity { results.append((index, entity)) }
                guard let (nextIndex, nextURL) = iterator.next() else { continue }
                group.addTask { await Self.loadSharedImage(at: nextURL, index: nextIndex) }
            }

            return results
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }
    
    public func clearSharedImages(appGroupID: String) async throws {
        let fileURLs = try sharedImageURLs(for: appGroupID)
        
        for url in fileURLs {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                Logger.data.error("파일 정리 실패: \(url.lastPathComponent) - \(error.localizedDescription)")
            }
        }
    }
}

private extension FileManagerSharedImageRepository {
    static func loadSharedImage(at fileURL: URL, index: Int) async -> (Int, ImageUploadEntity?) {
        await Task.detached(priority: .userInitiated) {
            do {
                let data = try Data(contentsOf: fileURL)
                return (
                    index,
                    ImageUploadEntity(data: data, format: .jpeg, size: data.count)
                )
            } catch {
                Logger.data.error("공유 이미지 로드 실패: \(fileURL.lastPathComponent) - \(error.localizedDescription)")
                return (index, nil)
            }
        }.value
    }
}


// MARK: - Dependency

private enum SharedImageRepositoryKey: DependencyKey {
    static let liveValue: SharedImageRepository = FileManagerSharedImageRepository()
}

extension DependencyValues {
    var sharedImageRepository: SharedImageRepository {
        get { self[SharedImageRepositoryKey.self] }
        set { self[SharedImageRepositoryKey.self] = newValue }
    }
}
