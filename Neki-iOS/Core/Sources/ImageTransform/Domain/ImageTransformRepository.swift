//
//  ImageTransformRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 3/14/26.
//

import Foundation

public protocol ImageTransformRepository: Sendable {
    func transform(data: Data) async throws -> Data
}

public enum ImageTransformRepositoryError: LocalizedError {
    case modelLoadFailed
    case destinationCreationFailed
    case dataCompressionFailed
    case renderingFailed
    
    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed: return "AI 모델을 불러오는데 실패했습니다."
        case .destinationCreationFailed: return "데이터 저장소를 생성할 수 없습니다."
        case .dataCompressionFailed: return "이미지 압축에 실패했습니다."
        case .renderingFailed: return "이미지 렌더링에 실패했습니다."
        }
    }
}
