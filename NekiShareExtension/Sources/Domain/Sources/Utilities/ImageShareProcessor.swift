//
//  ImageShareProcessor.swift
//  NekiShareExtension
//
//  Created by SwainYun on 3/20/26.
//

import Foundation
import UniformTypeIdentifiers

enum ImageShareProcessorError: Error {
    case noImageFound
    case loadFailed(Error)
    case invalidProvider
    case unknown
}

protocol ImageShareUseCase {
    func extractImageProviders(from extensionItems: [NSExtensionItem]) -> [NSItemProvider]
    func fetchPreviewData(from provider: NSItemProvider) async throws -> Data
    func share(providers: [NSItemProvider]) async throws
}

struct ImageShareProcessor {
    private let repository: ExtensionImageRepository
    
    init(repository: ExtensionImageRepository) { self.repository = repository }
    
    private func processAndSaveImage(from provider: NSItemProvider) async throws {
        let suggestedName = provider.suggestedName
        
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error = error { return continuation.resume(throwing: ImageShareProcessorError.loadFailed(error)) }
                
                guard let url = url else { return continuation.resume(throwing: ImageShareProcessorError.unknown) }
                let fileName = suggestedName ?? url.lastPathComponent
                
                do {
                    try repository.saveImage(from: url, fileName: fileName)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}


// MARK: - ImageShareProcessor + ImageShareUseCase

extension ImageShareProcessor: ImageShareUseCase {
    func extractImageProviders(from extensionItems: [NSExtensionItem]) -> [NSItemProvider] {
        extensionItems.compactMap { $0.attachments }.flatMap { $0 }.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
    }
    
    func fetchPreviewData(from provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error = error { return continuation.resume(throwing: ImageShareProcessorError.loadFailed(error)) }
                guard let data = data else { return continuation.resume(throwing: ImageShareProcessorError.unknown) }
                continuation.resume(returning: data)
            }
        }
    }
    
    func share(providers: [NSItemProvider]) async throws {
        guard providers.isEmpty == false else { throw ImageShareProcessorError.noImageFound }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask { try await processAndSaveImage(from: provider) }
            }
            
            for try await _ in group {}
        }
    }
}
