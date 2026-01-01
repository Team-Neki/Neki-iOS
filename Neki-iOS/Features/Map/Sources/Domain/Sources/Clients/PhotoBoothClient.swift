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


// MARK: - PhotoBoothClient + Logic Implementation

extension PhotoBoothClient {
    static func liveImplementation(bounds: GeographicBoundingBox) async throws -> [PhotoBooth] {
        // TODO: 추후 Repository 및 서버 연결하여 실질 코드로 변경해야 합니다.
        // 1. 네트워크 지연 시나리오를 모방함 (0.5 ~ 1.5초)
        try await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.5...1.5) * 1_000_000_000))
        
        // 2. 랜덤 데이터 생성 설정
        let count = Int.random(in: 20...50) // 20~50개 가짜 POI 생성
        var mockData: [PhotoBooth] = []
        
        // 3. 요청된 범위(Bounds) 내에서 랜덤 좌표 생성
        for i in 0..<count {
            let randomLatitude = Double.random(in: bounds.minLatitude...bounds.maxLatitude)
            let randomLongitude = Double.random(in: bounds.minLongitude...bounds.maxLongitude)
            
            // 랜덤 브랜드 선택
            let randomBrand = PhotoBoothBrand.allCases.randomElement() ?? .unknown
            
            let booth = PhotoBooth(
                id: UUID(),
                brand: randomBrand,
                name: "\(randomBrand.displayName) 강남 \(i)호점",
                coordinate: GeographicCoordinate(latitude: randomLatitude, longitude: randomLongitude),
                address: "서울특별시 강남구 테헤란로 \(Int.random(in: 100...999))",
                detailInformationURL: URL(string: "https://map.kakao.com")
            )
            
            mockData.append(booth)
        }
        
        return mockData
    }
    
    static func previewImplementation(bounds: GeographicBoundingBox) async throws -> [PhotoBooth] {
        [
            PhotoBooth(
                id: UUID(),
                brand: .photogray,
                name: "강남 1호점",
                coordinate: .init(latitude: 37.498095, longitude: 127.027610),
                address: "서울특별시 강남구 역삼동 821-1"
            )
        ]
    }
}


// MARK: - PhotoBoothClient + DependencyKey

extension PhotoBoothClient: DependencyKey {
    public static let liveValue = Self(fetchPhotoBooths: liveImplementation)
    
    public static let testValue = Self()
    
    public static let previewValue = Self(fetchPhotoBooths: previewImplementation)
}


// MARK: - PhotoBoothClient + Dependency Accessor

public extension DependencyValues {
    var photoBoothClient: PhotoBoothClient {
        get { self[PhotoBoothClient.self] }
        set { self[PhotoBoothClient.self] = newValue }
    }
}
