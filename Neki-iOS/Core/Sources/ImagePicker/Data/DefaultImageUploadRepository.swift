//
//  DefaultImageUploadRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import Foundation
import ComposableArchitecture
import os

public struct DefaultImageUploadRepository: ImageUploadRepository {
    
    @Dependency(\.networkProvider) var networkProvider
    
    public init() {}
    
    public func upload(items: [ImageUploadEntity], mediaType: ImageMediaType) async throws -> [Int] {
        Logger.network.debug("🚀 이미지 업로드 시작 (총 \(items.count)장, 타입: \(mediaType.rawValue))")
        
        // MARK: - Presigned URL 일괄요청
        
        let requestItems = items.map { item in
            PresignedURLRequestData(
                filename: UUID().uuidString,
                contentType: item.contentType,
                mediaType: mediaType.rawValue,
                width: item.width,
                height: item.height,
                size: item.size
            )
        }
        let requestDTO = PresignedURLRequestDTO(items: requestItems)
        let presignedEndpoint = ImageUploadEndpoint.getPresignedURL(request: requestDTO)
        
        let response: PresignedURLResponseDTO
        do {
            Logger.network.debug("📡 Presigned URL 요청 중...")
            response = try await networkProvider.request(endpoint: presignedEndpoint)
        } catch NetworkError.unauthorizedError {
            throw UploadError.authenticationRequired
        } catch {
            Logger.network.error("❌ Presigned URL 요청 실패: \(error.localizedDescription)")
            throw error
        }
        
        guard let responseItems = response.data?.items, responseItems.count == items.count else {
            Logger.network.error("❌ 응답 데이터가 누락되었거나 요청한 개수와 일치하지 않습니다.")
            throw UploadError.presignedUrlFailed
        }
        
        // 결과로 반환할 mediaID들
        let finalMediaIDs = responseItems.map { $0.mediaID }
        
        
        // MARK: - S3 병렬 업로드
        
        let uploadTasks = Array(zip(items, responseItems))
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, taskInfo) in uploadTasks.enumerated() {
                let entity = taskInfo.0
                let responseItem = taskInfo.1
                
                group.addTask {
                    let uploadEndpoint = ImageUploadEndpoint.uploadToS3(
                        presignedURL: responseItem.uploadTicket,
                        data: entity.data,
                        contentType: responseItem.contentType
                    )
                    
                    do {
                        _ = try await networkProvider.requestVoid(endpoint: uploadEndpoint)
                        Logger.network.debug("[\(index+1)] ✅ S3 업로드 성공 (Media ID: \(responseItem.mediaID))")
                    } catch {
                        Logger.network.error("[\(index+1)] ❌ S3 업로드 실패")
                        throw error // 하나라도 실패하면 전체 에러 발생
                    }
                }
            }
            
            try await group.waitForAll()
        }
        
        Logger.network.debug("✨ 모든 이미지 업로드 완료! (결과 ID: \(finalMediaIDs))")
        
        return finalMediaIDs
    }
    
}

private enum ImageUploadRepositoryKey: DependencyKey {
    static let liveValue: any ImageUploadRepository = DefaultImageUploadRepository()
}

extension DependencyValues {
    var imageUploadRepository: any ImageUploadRepository {
        get { self[ImageUploadRepositoryKey.self] }
        set { self[ImageUploadRepositoryKey.self] = newValue }
    }
}
