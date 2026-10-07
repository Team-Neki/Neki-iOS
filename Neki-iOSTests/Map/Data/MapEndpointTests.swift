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
}
