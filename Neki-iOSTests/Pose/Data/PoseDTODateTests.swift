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
    @Test("사용하지 않는 포즈 createdAt이 잘못되어도 포즈 응답을 디코딩한다")
    func decode_ignoresUnusedCreatedAt() throws {
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
              "createdAt": "invalid"
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ServerDateCodec.dateDecodingStrategy

        let pose = try decoder.decode(PoseDTO.self, from: data).toEntity()

        #expect(pose.id == 1)
    }
}
