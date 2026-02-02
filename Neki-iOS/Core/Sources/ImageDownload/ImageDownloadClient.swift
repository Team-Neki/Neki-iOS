//
//  ImageDownloadClient.swift
//  Neki-iOS
//
//  Created by OneTen on 2/2/26.
//

import Foundation
import Dependencies
import DependenciesMacros
import Photos
import os

@DependencyClient
public struct ImageDownloadClient {
    public var downloadImages: (_ urls: [URL]) async throws -> Int
}

extension ImageDownloadClient: DependencyKey {
    public static var liveValue: ImageDownloadClient {
        
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
                            // 실패하는 경우가 있을지는 모르겠지만 혹시 모르니 작성
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
        
        func imageDownload(url: URL) async throws {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
        }
        
        return ImageDownloadClient(
            downloadImages: downloadImages
        )
    }
}

public extension DependencyValues {
    var imageDownloadClient: ImageDownloadClient {
        get { self[ImageDownloadClient.self] }
        set { self[ImageDownloadClient.self] = newValue }
    }
}
