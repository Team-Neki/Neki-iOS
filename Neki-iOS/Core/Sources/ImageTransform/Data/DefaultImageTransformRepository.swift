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

public final class DefaultImageTransformRepository: ImageTransformRepository {
    
    private let modelTask: Task<VNCoreMLModel, Error>
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    
    public init() {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        self.modelTask = Task {
            let coreML = try whiteboxcartoonization(configuration: config).model
            return try VNCoreMLModel(for: coreML)
        }
    }
    
    public func transform(data inputData: Data) async throws -> Data {
        let visionModel = try await modelTask.value
        
        return try await Task(priority: .userInitiated) {
            let request = VNCoreMLRequest(model: visionModel)
            request.imageCropAndScaleOption = .scaleFit
            
            let handler = VNImageRequestHandler(data: inputData)
            try handler.perform([request])
            
            return try self.extractData(from: request.results)
        }.value
    }
}


// MARK: - DefaultImageTransformRepository Private Helpers

private extension DefaultImageTransformRepository {
    
    /// Vision 결과물을 추출하여 최종 PNG Data로 변환하는 로직
    func extractData(from results: [VNObservation]?) throws -> Data {
        // Vision 결과물(CVPixelBuffer)
        guard let observations = results as? [VNPixelBufferObservation],
              let pixelBuffer = observations.first?.pixelBuffer else {
            throw ImageTransformRepositoryError.renderingFailed
        }
        
        // 픽셀 데이터를 이미지(CIImage -> CGImage)로 렌더링
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let outputCGImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw ImageTransformRepositoryError.renderingFailed
        }
        
        // 렌더링된 이미지를 PNG 형식의 Data로 압축
        return try compressToPNG(cgImage: outputCGImage)
    }
    
    /// CGImage를 PNG Data로 압축하는 메서드 (너무 어렵다...)
    /// UIImage(cgImage:).pngData() 이거 쓰면 딸깍이긴 하지만 Data 레이어에 UIKit 의존성이 생겨버림..
    func compressToPNG(cgImage: CGImage) throws -> Data {
        guard let cfMutableData = CFDataCreateMutable(kCFAllocatorDefault, 0) else {
            throw ImageTransformRepositoryError.destinationCreationFailed
        }
        
        guard let destination = CGImageDestinationCreateWithData(
            cfMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageTransformRepositoryError.destinationCreationFailed
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        
        if CGImageDestinationFinalize(destination) {
            return cfMutableData as Data
        } else {
            throw ImageTransformRepositoryError.dataCompressionFailed
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
