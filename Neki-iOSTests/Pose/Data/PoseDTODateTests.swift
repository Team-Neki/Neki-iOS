//
//  PoseDTODateTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 11/6/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct PoseDTODateTests {
    @Test("포즈 createdAt은 KST 무오프셋 서버 계약으로 디코딩한다")
    func decode_createdAtAsKST() throws {
        let data = Data(
            """
            {
              "poseId": 1,
              "headCount": "TWO",
              "imageUrl": "https://example.com/pose.jpg",
              "scrap": false,
              "contentType": "image/jpeg",
              "width": 1080,
              "height": 1440,
              "createdAt": "2025-12-23T16:09:00"
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ServerDateCodec.dateDecodingStrategy

        let pose = try decoder.decode(PoseDTO.self, from: data)

        #expect(pose.createdAt == Date(timeIntervalSince1970: 1_766_473_740))
    }
}
