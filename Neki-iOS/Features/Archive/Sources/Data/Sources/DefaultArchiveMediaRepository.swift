//
//  DefaultArchiveMediaRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/3/26.
//

import Foundation
import Dependencies
import Kingfisher
import UIKit

struct DefaultArchiveMediaRepository: ArchiveMediaRepository {
    func fetchOriginalImageData(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            KingfisherManager.shared.retrieveImage(
                with: url,
                options: [.cacheOriginalImage]
            ) { result in
                switch result {
                case let .success(value):
                    guard let data = value.data() else {
                        continuation.resume(throwing: ArchiveMediaError.originalImageDataUnavailable)
                        return
                    }
                    continuation.resume(returning: data)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @MainActor
    func shareInstagramStory(imageData: Data) async throws -> Bool {
        guard let urlScheme = URL(string: "instagram-stories://share?source_application=Neki"),
              UIApplication.shared.canOpenURL(urlScheme)
        else { return false }

        let pasteboardItems: [[String: Any]] = [
            ["com.instagram.sharedSticker.backgroundImage": imageData]
        ]
        UIPasteboard.general.setItems(
            pasteboardItems,
            options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
        )
        await UIApplication.shared.open(urlScheme)
        return true
    }
}

private enum ArchiveMediaError: Error {
    case originalImageDataUnavailable
}

private enum ArchiveMediaRepositoryKey: DependencyKey {
    static let liveValue: ArchiveMediaRepository = DefaultArchiveMediaRepository()
}

extension DependencyValues {
    var archiveMediaRepository: ArchiveMediaRepository {
        get { self[ArchiveMediaRepositoryKey.self] }
        set { self[ArchiveMediaRepositoryKey.self] = newValue }
    }
}
