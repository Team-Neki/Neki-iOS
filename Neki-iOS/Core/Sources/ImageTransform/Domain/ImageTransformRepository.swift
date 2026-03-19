//
//  ImageTransformRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 3/14/26.
//

import Foundation
import CoreGraphics

public protocol ImageTransformRepository: Sendable {
    func transform(image: CGImage) async throws -> CGImage
}

public enum ImageTransformRepositoryError: LocalizedError {
    case modelLoadFailed
    case renderingFailed
    
    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed: return "AI 모델을 불러오는데 실패했습니다."
        case .renderingFailed: return "이미지 렌더링에 실패했습니다."
        }
    }
}
