//
//  PhotoBoothClient.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/31/25.
//

import Foundation
import ComposableArchitecture

@DependencyClient
public struct PhotoBoothClient {
    /// 지도 영역(bounds) 내의 포토부스 데이터를 가져옵니다.
    public var fetchPhotoBooths: @Sendable (_ bounds: GeographicBoundingBox) async throws -> AsyncStream<[PhotoBooth]>
}


// MARK: - PhotoBoothClient + DependencyKey

extension PhotoBoothClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.photoBoothRepository) var photoBoothRepository
        
        return PhotoBoothClient { bounds in
            await photoBoothRepository.readPhotoBooths(in: bounds)
        }
    }()
}


// MARK: - PhotoBoothClient + Dependency Accessor

public extension DependencyValues {
    var photoBoothClient: PhotoBoothClient {
        get { self[PhotoBoothClient.self] }
        set { self[PhotoBoothClient.self] = newValue }
    }
}
