//
//  DefaultImageDownloadRepository.swift
//  Neki-iOS
//
//  Created by Codex on 7/8/26.
//

import Dependencies
import Foundation
import Photos
import os

struct DefaultImageDownloadRepository: ImageDownloadRepository {
    func downloadImages(urls: [URL]) async throws -> Int {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            Logger.domain.error("‼️ 갤러리 접근 권한이 없습니다.")
            return 0
        }

        return await withTaskGroup(of: Bool.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        try await imageDownload(url: url)
                        return true
                    } catch {
                        Logger.domain.error("❌ 이미지 다운로드 실패 (\(url)): \(error)")
                        return false
                    }
                }
            }

            var successCount = 0
            for await isSuccess in group {
                if isSuccess { successCount += 1 }
            }
            return successCount
        }
    }

    private func imageDownload(url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }
}

private enum ImageDownloadRepositoryKey: DependencyKey {
    static let liveValue: ImageDownloadRepository = DefaultImageDownloadRepository()
}

extension DependencyValues {
    var imageDownloadRepository: ImageDownloadRepository {
        get { self[ImageDownloadRepositoryKey.self] }
        set { self[ImageDownloadRepositoryKey.self] = newValue }
    }
}
