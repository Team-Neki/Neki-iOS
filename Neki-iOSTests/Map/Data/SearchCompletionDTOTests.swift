//
//  SearchCompletionDTOTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/7/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct SearchCompletionDTOTests {
    @Test("자동완성 응답에서 후보의 keyword·거리와 filterGroup을 읽는다")
    func response_decodesItemsAndFilterGroup() throws {
        let data = Data(
            """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": {
                "items": [
                  { "keyword": "강남역 2호선", "distanceKm": 0.1 },
                  { "keyword": "강남역 신분당선", "distanceKm": null }
                ],
                "hasNext": false,
                "totalCount": 2,
                "filterGroup": {
                  "brandFilter": { "brands": [{ "brandId": 1 }] },
                  "sortFilter": { "type": "DEFAULT" }
                }
              }
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(BaseResponseDTO<SearchCompletionDTO.Response>.self, from: data)
        let completion = try #require(response.data)

        #expect(completion.items.map(\.keyword) == ["강남역 2호선", "강남역 신분당선"])
        #expect(completion.items.map(\.distanceKm) == [0.1, nil])
        #expect(completion.hasNext == false)
        #expect(completion.filterGroup.brandFilter?.brands?.map(\.brandID) == [1])
        #expect(completion.filterGroup.sortFilter?.type == "DEFAULT")
    }

    @Test("자동완성 응답을 종류·keyword·filterGroup·거리를 담은 후보 페이지로 바꾼다")
    func response_toEntity_buildsCandidatesSharingFilterGroup() throws {
        let data = Data(
            """
            {
              "items": [
                { "keyword": "포토이즘 강남1호점", "distanceKm": 0.5 },
                { "keyword": "포토이즘 강남2호점", "distanceKm": null }
              ],
              "hasNext": true,
              "totalCount": 12,
              "filterGroup": {
                "brandFilter": { "brands": [{ "brandId": 1 }] },
                "sortFilter": { "type": "DEFAULT" }
              }
            }
            """.utf8
        )

        let page = try JSONDecoder().decode(SearchCompletionDTO.Response.self, from: data).toEntity(type: .photoBooth)

        // 조회 조건은 검색어로 정해지므로 같은 응답의 후보가 모두 같은 값을 담습니다.
        let filterGroup = PhotoBoothSearchFilterGroup(brandIDs: [1], sortType: "DEFAULT")
        #expect(page == PhotoBoothSearchCandidatePage(
            type: .photoBooth,
            candidates: [
                PhotoBoothSearchCandidate(
                    type: .photoBooth,
                    keyword: "포토이즘 강남1호점",
                    filterGroup: filterGroup,
                    distance: GeographicDistance(meters: 500)
                ),
                PhotoBoothSearchCandidate(type: .photoBooth, keyword: "포토이즘 강남2호점", filterGroup: filterGroup)
            ],
            hasNext: true
        ))
    }

    @Test("km 거리를 앱의 다른 거리와 같은 m 단위로 바꾼다", arguments: zip([0.1, 0.3, 1.0, 2.3, 16.0], [100, 300, 1000, 2300, 16_000]))
    func item_toEntity_convertsKilometersToMeters(distanceKm: Double, meters: Int) {
        let item = SearchCompletionDTO.Response.Item(keyword: "강남역 2호선", distanceKm: distanceKm)

        let candidate = item.toEntity(type: .subwayStation, filterGroup: .init())

        // 0.3 * 1000처럼 곱셈에서 생기는 소수 오차 없이 정수 m가 되어야 합니다.
        #expect(candidate.distance == GeographicDistance(meters: meters))
    }

    @Test(
        "filterGroup은 엔티티를 거쳐 요청에 담겨도 받은 모양 그대로 돌아간다",
        arguments: [
            #"{"brandFilter":{"brands":[{"brandId":1}]},"sortFilter":{"type":"DEFAULT"}}"#,
            #"{"brandFilter":{"brands":[]},"sortFilter":{"type":"DEFAULT"}}"#,
            #"{}"#
        ]
    )
    func filterGroup_roundTripsThroughEntity(json: String) throws {
        let receivedData = Data(json.utf8)
        let filterGroup = try JSONDecoder().decode(SearchFilterGroupDTO.self, from: receivedData).toEntity()

        let sentData = try MapEndpoint.defaultEncoder.encode(SearchFilterGroupDTO(filterGroup))

        #expect(try jsonObject(from: sentData) == jsonObject(from: receivedData))
    }
}


// MARK: - Helpers

private extension SearchCompletionDTOTests {
    /// 키 순서와 상관없이 비교할 수 있도록 JSON을 객체로 되돌립니다.
    func jsonObject(from data: Data) throws -> NSDictionary {
        try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }
}
