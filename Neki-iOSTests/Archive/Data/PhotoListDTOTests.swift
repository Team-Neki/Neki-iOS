//
//  PhotoListDTOTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 7/3/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct PhotoListDTOTests {
    @Test(
        "지원하는 서버 날짜 형식을 공용 계약으로 Date로 변환한다",
        arguments: [
            ("2026-07-03T10:20:30.123456Z", "2026-07-03T10:20:30.123456Z"),
            ("2026-07-03T10:20:30.123456", "2026-07-03T01:20:30.123456Z"),
            ("2026-07-03T10:20:30Z", "2026-07-03T10:20:30Z"),
            ("2026-07-03T10:20:30", "2026-07-03T01:20:30Z"),
            ("2026-07-03T10:20:30+09:00", "2026-07-03T01:20:30Z")
        ]
    )
    func toEntity_parsesSupportedDateFormats(dateValue: String, expectedValue: String) throws {
        let data = Data(
            """
            {
              "items": [{
                "photoId": 1,
                "imageUrl": "https://example.com/1.jpg",
                "folderId": null,
                "favorite": false,
                "contentType": "image/jpeg",
                "createdAt": "\(dateValue)",
                "memo": null,
                "width": 1080,
                "height": 1440
              }],
              "hasNext": false,
              "totalCount": 1
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ServerDateCodec.dateDecodingStrategy
        let response = try decoder.decode(PhotoListDTO.PhotoListData.self, from: data)
        let photo = try #require(response.toEntity().first)
        let expectedDate = try ServerDateCodec().decode(expectedValue)

        #expect(abs(photo.createdAt.timeIntervalSince(expectedDate)) < 0.001)
        #expect(photo.memo.isEmpty)
    }

    @Test("잘못된 서버 날짜는 현재 시각으로 대체하지 않고 디코딩에 실패한다")
    func toEntity_whenDateIsInvalid_throwsDecodingError() throws {
        let data = Data(
            """
            {
              "items": [{
                "photoId": 1,
                "imageUrl": "https://example.com/1.jpg",
                "folderId": null,
                "favorite": false,
                "contentType": "image/jpeg",
                "createdAt": "invalid",
                "memo": null,
                "width": null,
                "height": null
              }],
              "hasNext": false,
              "totalCount": 1
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ServerDateCodec.dateDecodingStrategy
        #expect(throws: DecodingError.self) {
            try decoder.decode(PhotoListDTO.PhotoListData.self, from: data)
        }
    }
}
