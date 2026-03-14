//
//  DefaultImageTransformRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 3/14/26.
//

import Foundation
import CoreML
import Vision
import UniformTypeIdentifiers
import ComposableArchitecture
import CoreImage
import os

public enum ImageTransformDataError: LocalizedError {
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

public final class DefaultImageTransformRepository: ImageTransformRepository {
    
    private var modelTasks: [ImageTransformModel: Task<VNCoreMLModel, Error>] = [:]
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    
    public init() {
            // init에서는 무거운 작업을 하지 않고, 백그라운드에서 모델을 로드하도록 Task만 걸어둡니다. (메인 스레드 멈춤 방지)
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            modelTasks[.whiteboxCartoonization] = Task {
                let coreML = try whiteboxcartoonization(configuration: config).model
                return try VNCoreMLModel(for: coreML)
            }
            
            modelTasks[.anime2Sketch] = Task {
                let coreML = try anime2sketch(configuration: config).model
                return try VNCoreMLModel(for: coreML)
            }
        }
    
    public func transform(data inputData: Data, model type: ImageTransformModel) async throws -> Data {
        guard let task = modelTasks[type], let visionModel = try? await task.value else {
                    throw ImageTransformDataError.modelLoadFailed
                }
        
        return try await withCheckedThrowingContinuation { continuation in
            
            /// VNCoreMLRequest: - CoreML 모델을 기반으로 한 이미지 분석 요청 객체
            let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                guard let self = self else {
                                    continuation.resume(throwing: CancellationError())
                                    return
                                }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                do {
                    let finalPNGData = try self.extractData(from: request.results)
                    continuation.resume(returning: finalPNGData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            /// imageCropAndScaleOption: - 원본 이미지가 모델의 요구 사이즈(512x512)와 다를 경우 어떻게 리사이징할지
            request.imageCropAndScaleOption = .scaleFit
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    /// VNImageRequestHandler: - VNRequest를 실행하는 객체
                    let handler = VNImageRequestHandler(data: inputData)
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}


// MARK: - DefaultImageTransformRepository Private Helpers

private extension DefaultImageTransformRepository {
    
    /// Vision 결과물을 추출하여 최종 PNG Data로 변환하는 로직
    func extractData(from results: [VNObservation]?) throws -> Data {
        // Vision 결과물(CVPixelBuffer)
        guard let observations = results as? [VNPixelBufferObservation],
              let pixelBuffer = observations.first?.pixelBuffer else {
            throw ImageTransformDataError.renderingFailed
        }
        
        // 픽셀 데이터를 이미지(CIImage -> CGImage)로 렌더링
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let outputCGImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw ImageTransformDataError.renderingFailed
        }
        
        // 렌더링된 이미지를 PNG 형식의 Data로 압축
        return try compressToPNG(cgImage: outputCGImage)
    }
    
    /// CGImage를 PNG Data로 압축하는 메서드 (너무 어렵다...)
    /// UIImage(cgImage:).pngData() 이거 쓰면 딸깍이긴 하지만 Data 레이어에 UIKit 의존성이 생겨버림..
    func compressToPNG(cgImage: CGImage) throws -> Data {
        guard let cfMutableData = CFDataCreateMutable(kCFAllocatorDefault, 0) else {
            throw ImageTransformDataError.destinationCreationFailed
        }
        
        guard let destination = CGImageDestinationCreateWithData(
            cfMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageTransformDataError.destinationCreationFailed
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        
        if CGImageDestinationFinalize(destination) {
            return cfMutableData as Data
        } else {
            throw ImageTransformDataError.dataCompressionFailed
        }
    }
}

private enum ImageTransformRepositoryKey: DependencyKey {
    static let liveValue: any ImageTransformRepository = DefaultImageTransformRepository()
}

extension DependencyValues {
    public var imageTransformRepository: any ImageTransformRepository {
        get { self[ImageTransformRepositoryKey.self] }
        set { self[ImageTransformRepositoryKey.self] = newValue }
    }
}
