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
        return try await withThrowingTaskGroup(of: (Int, Int).self) { group in
            
            var uploadedResults: [(Int, Int)] = []
            Logger.network.debug("🚀 이미지 업로드 시작 (총 \(items.count)장, 타입: \(mediaType.rawValue))")
            
            for (index, item) in items.enumerated() {
                group.addTask {
                    
                    // MARK: - PresignedURL 발급을 위한 UUID 및 파일명 생성
                    
                    let uuid = UUID().uuidString
                    let fileName = "\(uuid)"
                    Logger.data.debug("[\(index+1)] 파일명 생성: \(fileName) (Type: \(item.contentType))")
                    
                    let dto = PresignedURLRequestDTO(
                        filename: fileName,
                        contentType: item.contentType,
                        mediaType: mediaType.rawValue
                    )
                    
                    
                    // MARK: - Presigned URL 요청
                    
                    let presighnedEndpoint = PresignedEndpoint(requests: dto)
                    let response: PresignedURLResponseDTO
                    
                    do {
                        Logger.network.debug("[\(index+1)] Presigned URL 요청 중...")
                        response = try await networkProvider.request(endpoint: presighnedEndpoint)
                        Logger.network.debug("[\(index+1)] Presigned URL 요청 완료")
                    } catch {
                        Logger.network.error("[\(index+1)] ❌ Presigned URL 요청 실패: \(error.localizedDescription)")
                        throw error
                    }
                    
                    // 이미지 업로드 할 Presigned URL
                    guard let uploadUrl = response.data?.uploadURL else {
                        Logger.network.error("[\(index+1)] ❌ 응답에 uploadUrl이 없습니다.")
                        throw UploadError.presignedUrlFailed
                    }
                                        
                    // 성공 시 서버에 업로드 할 이미지 ID
                    guard let mediaID = response.data?.mediaID else {
                        Logger.network.error("[\(index+1)] ❌ 응답에 mediaID가 없습니다.")
                        throw UploadError.presignedUrlFailed
                    }
                    
                    
                    // MARK: - S3 업로드
                    
                    Logger.network.debug("[\(index+1)] S3 업로드 시작")
                    
                    let uploadImageEndpoint = UploadImageEndpoint(
                        presignedUrl: uploadUrl,
                        imageData: item.data,
                        contentType: item.contentType
                    )
                    
                    do {
                        let _ = try await networkProvider.requestVoid(endpoint: uploadImageEndpoint)
                        Logger.network.debug("[\(index+1)] ✅ S3 업로드 성공")
                    } catch {
                        Logger.network.error("[\(index+1)] ❌ S3 업로드 실패: \(error.localizedDescription)")
                        throw error
                    }
                    
                    return (index, mediaID)
                }
            }
            
            do {
                for try await result in group {
                    uploadedResults.append(result)
                }
            } catch {
                // TaskGroup 내부에서 에러 발생 시 (하나라도 실패하면 여기로 옴)
                Logger.network.error("❌ 이미지 업로드 중단됨 (하나 이상의 작업 실패): \(error.localizedDescription)")
                throw error // 에러 전파 (전체 실패 처리)
            }
            
            let sortedResult = uploadedResults
                .sorted { $0.0 < $1.0 }
                .map { $0.1 }
            
            Logger.network.debug("✨ 모든 이미지 업로드 완료! (이미지 ID: \(sortedResult))")
            
            return sortedResult
        }
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

public enum UploadError: Error {
    case presignedUrlFailed
    case uploadFailed
}
