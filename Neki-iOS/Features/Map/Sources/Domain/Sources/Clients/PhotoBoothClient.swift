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
    public var fetchPhotoBooths: @Sendable (_ bounds: GeographicBoundingBox) async throws -> [PhotoBooth]
}


// MARK: - PhotoBoothClient + DependencyKey

extension PhotoBoothClient: DependencyKey {
    public static let liveValue = Self { bounds in
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let filteredBooths = fixedMockBooths.filter { booth in
            bounds.contains(booth.coordinate)
        }
        
        return filteredBooths
    }
    
    public static let testValue = Self()
    
    public static let previewValue = Self { bounds in
        return fixedMockBooths.filter { booth in
            bounds.contains(booth.coordinate)
        }
    }
}


// MARK: - PhotoBoothClient + Dependency Accessor

public extension DependencyValues {
    var photoBoothClient: PhotoBoothClient {
        get { self[PhotoBoothClient.self] }
        set { self[PhotoBoothClient.self] = newValue }
    }
}


// MARK: - PhotoBoothClient + Mock

extension PhotoBoothClient {
    private static let fixedMockBooths: [PhotoBooth] = [
        .init(id: UUID(), brand: .life4cut, name: "인생네컷 강남점", coordinate: .init(latitude: 37.4981, longitude: 127.0276), address: "서울 강남구 1"),
        .init(id: UUID(), brand: .harufilm, name: "하루필름 역삼점", coordinate: .init(latitude: 37.4991, longitude: 127.0286), address: "서울 강남구 2"),
        .init(id: UUID(), brand: .photoism, name: "포토이즘 강남CGV점", coordinate: .init(latitude: 37.5015, longitude: 127.0260), address: "서울 강남구 3"),
        .init(id: UUID(), brand: .photogray, name: "포토그레이 신논현점", coordinate: .init(latitude: 37.5038, longitude: 127.0241), address: "서울 강남구 4"),
        .init(id: UUID(), brand: .planBStudio, name: "플랜비 강남역점", coordinate: .init(latitude: 37.4970, longitude: 127.0250), address: "서울 강남구 5"),
        .init(id: UUID(), brand: .life4cut, name: "인생네컷 서초점", coordinate: .init(latitude: 37.4950, longitude: 127.0290), address: "서울 서초구 1"),
        .init(id: UUID(), brand: .photosignature, name: "포토시그니처 뱅뱅사거리점", coordinate: .init(latitude: 37.4890, longitude: 127.0300), address: "서울 강남구 6")
    ]
}
