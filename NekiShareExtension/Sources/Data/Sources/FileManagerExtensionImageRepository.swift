//
//  FileManagerExtensionImageRepository.swift
//  NekiShareExtension
//
//  Created by SwainYun on 3/20/26.
//

import Foundation
import UniformTypeIdentifiers

struct FileManagerExtensionImageRepository: ExtensionImageRepository, @unchecked Sendable {
    let sharedDirectory: URL?
    
    private let fileManager: FileManager
    
    init(appGroupID: String, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        self.sharedDirectory = groupURL?.appendingPathComponent("SharedImages", conformingTo: .directory)
    }
    
    func saveImage(from sourceURL: URL, fileName: String) throws {
        guard let directory = sharedDirectory else { throw ExtensionImageRepositoryError.directoryNotFound }
        let destinationURL = directory.appendingPathComponent(fileName, conformingTo: .image)
        try ensureDirectoryExists(at: directory)
        try removeExistingFileIfNeeded(at: destinationURL)
        try copyFile(from: sourceURL, to: destinationURL)
    }
}

private extension FileManagerExtensionImageRepository {
    func ensureDirectoryExists(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path()) == false else { return }
        
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw ExtensionImageRepositoryError.cannotCreateDirectory
        }
    }
    
    func removeExistingFileIfNeeded(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path()) else { return }
        
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ExtensionImageRepositoryError.itemExistsAndRemoveFailed
        }
    }
    
    func copyFile(from sourceURL: URL, to destinationURL: URL) throws {
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw ExtensionImageRepositoryError.cannotWriteToDirectory
        }
    }
}
