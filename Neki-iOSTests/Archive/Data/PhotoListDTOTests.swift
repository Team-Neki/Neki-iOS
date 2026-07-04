//
//  PhotoListDTOTests.swift
//  Neki-iOSTests
//
//  Created by Codex on 7/3/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct PhotoListDTOTests {
    @Test(
        "지원하는 ISO 8601 형식을 Data 계층에서 Date로 변환한다",
        arguments: [
            "2026-07-03T10:20:30.123456Z",
            "2026-07-03T10:20:30.123456",
            "2026-07-03T10:20:30Z",
            "2026-07-03T10:20:30"
        ]
    )
    func toEntity_parsesSupportedDateFormats(dateValue: String) throws {
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

        let response = try JSONDecoder().decode(PhotoListDTO.PhotoListData.self, from: data)
        let photo = try #require(response.toEntity().first)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let nanosecond = dateValue.contains(".") ? 123_456_000 : 0
        let expectedDate = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 3,
            hour: 10,
            minute: 20,
            second: 30,
            nanosecond: nanosecond
        )))

        #expect(photo.createdAtRawValue == dateValue)
        #expect(abs(photo.createdAt.timeIntervalSince(expectedDate)) < 0.001)
        #expect(photo.memo.isEmpty)
    }

    @Test("잘못된 날짜는 기존 정책대로 현재 시각으로 대체한다")
    func toEntity_whenDateIsInvalid_usesCurrentDate() throws {
        let beforeParsing = Date()
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

        let response = try JSONDecoder().decode(PhotoListDTO.PhotoListData.self, from: data)
        let photo = try #require(response.toEntity().first)

        #expect(photo.createdAt >= beforeParsing)
        #expect(photo.createdAt <= Date())
    }
}
