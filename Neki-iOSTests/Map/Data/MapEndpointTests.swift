//
//  MapEndpointTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/7/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct MapEndpointTests {
    @Test("자동완성은 종류마다 completion 경로로 body 없이 GET 요청한다")
    func searchCompletion_usesCompletionPathWithGet() {
        let endpoints: [(endpoint: MapEndpoint, path: String)] = [
            (.searchCompletionRegions(keyword: "강남", page: 0, size: 20), "/search/completion/regions"),
            (.searchCompletionStations(keyword: "강남", page: 0, size: 20, origin: nil), "/search/completion/stations"),
            (.searchCompletionPhotoBooths(keyword: "강남", page: 0, size: 20, origin: nil), "/search/completion/photo-booths")
        ]

        for (endpoint, path) in endpoints {
            #expect(endpoint.path == path)
            #expect(endpoint.method == .get)
            #expect(endpoint.body == nil)
        }
    }

    @Test("지역 자동완성은 검색어와 페이지만 쿼리로 담는다")
    func searchCompletionRegions_sendsKeywordAndPageOnly() {
        let endpoint = MapEndpoint.searchCompletionRegions(keyword: "서울 강남", page: 1, size: 20)

        // 검색어는 서버가 앞뒤 공백과 연속 공백을 다듬으므로 입력한 그대로 담습니다.
        #expect(endpoint.queryParameters == ["keyword": "서울 강남", "page": "1", "size": "20"])
    }

    @Test("역·부스 자동완성은 기준 위치를 위도와 경도로 함께 담는다")
    func searchCompletion_withOrigin_sendsLatitudeAndLongitudeTogether() {
        let origin = GeographicCoordinate(latitude: 37.4979, longitude: 127.0276)
        let endpoints: [MapEndpoint] = [
            .searchCompletionStations(keyword: "강남", page: 0, size: 20, origin: origin),
            .searchCompletionPhotoBooths(keyword: "강남", page: 0, size: 20, origin: origin)
        ]

        for endpoint in endpoints {
            #expect(endpoint.queryParameters == [
                "keyword": "강남",
                "page": "0",
                "size": "20",
                "latitude": "37.4979",
                "longitude": "127.0276"
            ])
        }
    }

    @Test("기준 위치가 없으면 위도와 경도를 둘 다 뺀다")
    func searchCompletion_withoutOrigin_omitsLatitudeAndLongitude() {
        let endpoints: [MapEndpoint] = [
            .searchCompletionStations(keyword: "강남", page: 0, size: 20, origin: nil),
            .searchCompletionPhotoBooths(keyword: "강남", page: 0, size: 20, origin: nil)
        ]

        // 하나만 보내면 `D-01`이므로 둘 다 빼야 합니다.
        for endpoint in endpoints {
            #expect(endpoint.queryParameters == ["keyword": "강남", "page": "0", "size": "20"])
        }
    }

    @Test("부스 목록 요청은 후보의 keyword와 filterGroup을 그대로, 기준 위치를 userLocation으로 담는다")
    func searchResultPhotoBooths_sendsKeywordFilterGroupAndUserLocation() throws {
        let endpoint = MapEndpoint.searchResultPhotoBooths(dto: .init(
            keyword: "강남구 포토이즘",
            filterGroup: PhotoBoothSearchFilterGroup(brandIDs: [1], sortType: "DEFAULT"),
            userCoordinate: GeographicCoordinate(latitude: 37.4979, longitude: 127.0276)
        ))

        #expect(endpoint.path == "/search/photo-booths")
        #expect(endpoint.method == .post)
        let expectedBody: [String: Any] = [
            "keyword": "강남구 포토이즘",
            "filterGroup": [
                "brandFilter": ["brands": [["brandId": 1]]],
                "sortFilter": ["type": "DEFAULT"]
            ] as [String: Any],
            "userLocation": ["latitude": 37.4979, "longitude": 127.0276]
        ]
        #expect(try bodyObject(of: endpoint) == expectedBody as NSDictionary)
    }

    @Test("기준 위치가 없으면 userLocation 키를 빼고, 조건이 없는 filterGroup도 {}로 담는다")
    func searchResultPhotoBooths_withoutUserLocation_keepsEmptyFilterGroup() throws {
        let endpoint = MapEndpoint.searchResultPhotoBooths(dto: .init(
            keyword: "서울특별시 강남구",
            filterGroup: PhotoBoothSearchFilterGroup(),
            userCoordinate: nil
        ))

        // `filterGroup`을 빼면 `D-01`이므로 조건이 없어도 빈 객체로 담습니다.
        let expectedBody: [String: Any] = [
            "keyword": "서울특별시 강남구",
            "filterGroup": [String: Any]()
        ]
        #expect(try bodyObject(of: endpoint) == expectedBody as NSDictionary)
    }

    @Test("필터 요청은 부스 목록과 같은 keyword와 filterGroup만 담고 userLocation은 담지 않는다")
    func searchFilter_sendsKeywordAndFilterGroupOnly() throws {
        let endpoint = MapEndpoint.searchFilter(dto: .init(
            keyword: "강남역 2호선",
            filterGroup: PhotoBoothSearchFilterGroup(brandIDs: [], sortType: "DEFAULT")
        ))

        // 정의되지 않은 필드를 담으면 `D-01`이므로 `userLocation` 키가 없어야 합니다.
        #expect(endpoint.path == "/search/filter")
        #expect(endpoint.method == .post)
        let expectedBody: [String: Any] = [
            "keyword": "강남역 2호선",
            "filterGroup": [
                "brandFilter": ["brands": [Any]()],
                "sortFilter": ["type": "DEFAULT"]
            ] as [String: Any]
        ]
        #expect(try bodyObject(of: endpoint) == expectedBody as NSDictionary)
    }
}


// MARK: - Helpers

private extension MapEndpointTests {
    /// 요청 body를 실제 요청과 같은 인코더로 인코딩한 뒤, 키 순서와 상관없이 비교할 수 있도록 객체로 되돌립니다.
    func bodyObject(of endpoint: MapEndpoint) throws -> NSDictionary {
        let body = try #require(endpoint.body)
        let data = try MapEndpoint.defaultEncoder.encode(body)
        return try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }
}
