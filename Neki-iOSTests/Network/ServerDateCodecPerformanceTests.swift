//
//  ServerDateCodecPerformanceTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 11/6/26.
//

import XCTest
@testable import Neki_iOS

final class ServerDateCodecPerformanceTests: XCTestCase {
    func testRepresentativeBatchDecodingPerformance() throws {
        let codec = ServerDateCodec()
        let values = [
            "2025-12-23T16:09:00",
            "2025-12-23T16:09:00.123456",
            "2025-12-23T07:09:00Z",
            "2025-12-23T16:09:00+09:00"
        ]

        measure {
            for _ in 0..<1_000 {
                for value in values {
                    _ = try? codec.decode(value)
                }
            }
        }
    }
}
