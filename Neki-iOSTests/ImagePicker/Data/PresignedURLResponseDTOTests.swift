//
//  PresignedURLResponseDTOTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 11/6/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct PresignedURLResponseDTOTests {
    @Test("사용하지 않는 expiresIn이 KST 형식으로 포함되어도 업로드 티켓을 디코딩한다")
    func decode_ignoresExpiresIn() throws {
        let data = Data(
            """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": {
                "method": "PUT",
                "expiresIn": "2025-12-23T16:09:00",
                "items": [{
                  "mediaId": 1,
                  "uploadTicket": "https://example.com/upload",
                  "contentType": "image/jpeg"
                }]
              }
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(PresignedURLResponseDTO.self, from: data)

        #expect(response.data?.items.first?.mediaID == 1)
    }
}
