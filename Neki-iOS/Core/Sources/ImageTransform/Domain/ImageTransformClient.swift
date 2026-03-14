//
//  ImageTransformClient.swift
//  Neki-iOS
//
//  Created by OneTen on 3/14/26.
//

import Foundation
import ComposableArchitecture

public struct ImageTransformClient {
    public var transformImage: @Sendable (_ image: Data) async throws -> Data
}

extension ImageTransformClient: DependencyKey {
    public static let liveValue: ImageTransformClient = {
        @Dependency(\.imageTransformRepository) var repository
        
        return ImageTransformClient(
            transformImage: { inputData in
                return try await repository.transform(data: inputData)
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
        transformImage: { inputData in
            return inputData
        }
    )
}
