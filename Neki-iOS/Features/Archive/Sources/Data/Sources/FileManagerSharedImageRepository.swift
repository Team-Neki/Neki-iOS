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

public struct FileManagerSharedImageRepository {
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
