//
//  ImageTransformClient.swift
//  Neki-iOS
//
//  Created by OneTen on 3/14/26.
//

import Foundation
import ComposableArchitecture
import CoreGraphics

public struct ImageTransformClient {
    public var transformImage: @Sendable (_ image: CGImage) async throws -> CGImage
}

extension ImageTransformClient: DependencyKey {
    public static let liveValue: ImageTransformClient = {
        @Dependency(\.imageTransformRepository) var repository
        
        return ImageTransformClient(
            transformImage: { inputImage in
                return try await repository.transform(image: inputImage)
            }
        )
    }()
}

extension DependencyValues {
    public var imageTransformClient: ImageTransformClient {
        get { self[ImageTransformClient.self] }
        set { self[ImageTransformClient.self] = newValue }
    }
}

extension ImageTransformClient: TestDependencyKey {
    public static let testValue = ImageTransformClient(
        transformImage: { inputImage in
            return inputImage
        }
    )
}
