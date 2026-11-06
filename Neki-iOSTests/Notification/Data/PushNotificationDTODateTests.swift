//
//  PushNotificationDTODateTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 11/6/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct PushNotificationDTODateTests {
    @Test("알림 createdAt은 공용 서버 시간 계약으로 한 번만 디코딩한다")
    func decode_createdAtAsKST() throws {
        let data = Data(
            """
            {
              "id": 1,
              "type": "NOTICE",
              "title": "제목",
              "body": "본문",
              "link": null,
              "createdAt": "2025-12-23T16:09:00"
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ServerDateCodec.dateDecodingStrategy

        let dto = try decoder.decode(PushNotificationDTO.self, from: data)
        let entity = dto.toEntity()

        #expect(entity.sentTime?.value == Date(timeIntervalSince1970: 1_766_473_740))
    }
}
