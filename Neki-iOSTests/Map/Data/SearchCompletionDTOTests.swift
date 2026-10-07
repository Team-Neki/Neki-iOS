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

    @Test(
        "filterGroup은 받은 모양 그대로 다시 인코딩한다",
        arguments: [
            #"{"brandFilter":{"brands":[{"brandId":1}]},"sortFilter":{"type":"DEFAULT"}}"#,
            #"{"brandFilter":{"brands":[]},"sortFilter":{"type":"DEFAULT"}}"#,
            #"{}"#
        ]
    )
    func filterGroup_reencodesReceivedShape(json: String) throws {
        let receivedData = Data(json.utf8)
        let filterGroup = try JSONDecoder().decode(SearchFilterGroupDTO.self, from: receivedData)

        let sentData = try MapEndpoint.defaultEncoder.encode(filterGroup)

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
