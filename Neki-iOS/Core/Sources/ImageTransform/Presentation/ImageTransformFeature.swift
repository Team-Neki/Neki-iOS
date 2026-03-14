//
//  ImageTransformFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 3/13/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
public struct ImageTransformFeature {
    @ObservableState
    public struct State: Equatable {
        public var inputImage: UIImage?
        public var outputImage: UIImage?
        public var isProcessing: Bool = false
        public var errorMessage: String?
                
        public init(inputImage: UIImage? = nil) {
            self.inputImage = inputImage
        }
    }
    
    public enum Action {
        case transformButtonTapped
        case transformCompleted(UIImage)
        case transformFailed(String)
        case closeButtonTapped
        case revertButtonTapped
    }
    
    @Dependency(\.imageTransformClient) var imageTransformClient
    @Dependency(\.dismiss) var dismiss
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                
            case .revertButtonTapped:
                state.outputImage = nil
                state.errorMessage = nil
                return .none
                
            case .transformButtonTapped:
                guard !state.isProcessing else { return .none }
                guard let inputImage = state.inputImage else { return .none }
                
                state.isProcessing = true
                state.errorMessage = nil
                state.outputImage = nil
                
                return .run { send in
                    do {
                        let originalRatio = inputImage.size.width / inputImage.size.height
                        
                        guard let squaredImage = inputImage.prepareSquareForCoreML(targetSize: 512),
                              let inputData = squaredImage.pngData() else {
                            throw ImageTransformError.processingFailed
                        }
                        
                        let resultData = try await imageTransformClient.transformImage(inputData)
                        
                        guard let resultSquareImage = UIImage(data: resultData) else {
                            throw ImageTransformError.resultDataReadFailed
                        }
                        
                        if let finalCroppedImage = resultSquareImage.cropToOriginalRatio(originalRatio: originalRatio) {
                            await send(.transformCompleted(finalCroppedImage))
                        } else {
                            await send(.transformCompleted(resultSquareImage))
                        }
                        
                    } catch {
                        await send(.transformFailed(error.localizedDescription))
                    }
                }
                
            case let .transformCompleted(transformedImage):
                state.isProcessing = false
                state.outputImage = transformedImage
                return .none
                
            case let .transformFailed(message):
                state.isProcessing = false
                state.errorMessage = message
                return .none
                
            case .closeButtonTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}

public enum ImageTransformError: LocalizedError {
    case processingFailed
    case resultDataReadFailed
    case custom(String)
    
    public var errorDescription: String? {
        switch self {
        case .processingFailed:
            return "이미지 전처리에 실패했습니다."
        case .resultDataReadFailed:
            return "결과 데이터를 읽어오지 못했습니다."
        case .custom(let message):
            return message
        }
    }
}
