//
//  DefaultImageDownloadRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/8/26.
//

import Dependencies
import Foundation
import Photos
import os

struct DefaultImageDownloadRepository: ImageDownloadRepository {
    private enum Constants {
        static let maxConcurrentDownloads = 5
    }

    func downloadImages(urls: [URL]) async throws -> Int {
        guard urls.isEmpty == false else { return 0 }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            Logger.domain.error("‼️ 갤러리 접근 권한이 없습니다.")
            return 0
        }

        return await withTaskGroup(of: Bool.self) { group in
            var iterator = urls.makeIterator()
            let initialTaskCount = min(Constants.maxConcurrentDownloads, urls.count)

            for _ in 0..<initialTaskCount {
                guard let url = iterator.next() else { break }
                Self.addDownloadTask(to: &group, url: url)
            }

            var successCount = 0
            while let isSuccess = await group.next() {
                if isSuccess { successCount += 1 }
                guard let url = iterator.next() else { continue }
                Self.addDownloadTask(to: &group, url: url)
            }
            return successCount
        }
    }

    private static func addDownloadTask(
        to group: inout TaskGroup<Bool>,
        url: URL
    ) {
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

    private static func imageDownload(url: URL) async throws {
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
