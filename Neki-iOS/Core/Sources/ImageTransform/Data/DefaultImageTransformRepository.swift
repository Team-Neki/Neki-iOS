//
//  DefaultImageTransformRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 3/14/26.
//

import Foundation
import Vision
import ComposableArchitecture
import CoreImage

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
    
    public func transform(image inputImage: CGImage) async throws -> CGImage {
        let visionModel = try await modelTask.value
        
        return try await Task(priority: .userInitiated) {
            let request = VNCoreMLRequest(model: visionModel)
            request.imageCropAndScaleOption = .scaleFit
            
            let handler = VNImageRequestHandler(cgImage: inputImage)
            try handler.perform([request])
            
            return try self.extractCGImage(from: request.results)
        }.value
    }
}


// MARK: - DefaultImageTransformRepository Private Helpers

private extension DefaultImageTransformRepository {
    func extractCGImage(from results: [VNObservation]?) throws -> CGImage {
        guard let observations = results as? [VNPixelBufferObservation],
              let pixelBuffer = observations.first?.pixelBuffer else {
            throw ImageTransformRepositoryError.renderingFailed
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let outputCGImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw ImageTransformRepositoryError.renderingFailed
        }
        
        return outputCGImage
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
