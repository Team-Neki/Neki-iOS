//
//  ServerLogRequestTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/2/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct ServerLogRequestTests {
    @Test("직렬화해 둔 로그를 그대로 이어 붙여 platform·logs 본문을 만든다")
    func body_joinsStoredLogs() {
        let body = ServerLogRequest.body(logs: [Data(#"{"a":1}"#.utf8), Data(#"{"b":2}"#.utf8)])

        #expect(String(decoding: body, as: UTF8.self) == #"{"platform":"IOS","logs":[{"a":1},{"b":2}]}"#)
    }

    @Test("요청 하나에는 로그를 500건까지 담는다")
    func fittingCount_limitsLogCount() {
        #expect(ServerLogRequest.fittingCount(logSizes: Array(repeating: 10, count: 600)) == 500)
        #expect(ServerLogRequest.fittingCount(logSizes: Array(repeating: 10, count: 3)) == 3)
    }

    @Test("요청 본문이 4MiB를 넘지 않을 때까지만 담는다")
    func fittingCount_limitsBodySize() {
        let envelopeSize = ServerLogRequest.body(logs: []).count
        let firstSize = ServerLogRequest.maxLogBytes
        let exactSecondSize = ServerLogRequest.maxBodyBytes - envelopeSize - firstSize - 1

        #expect(ServerLogRequest.fittingCount(logSizes: [firstSize, exactSecondSize, 1]) == 2)
        #expect(ServerLogRequest.fittingCount(logSizes: [firstSize, exactSecondSize + 1]) == 1)
        #expect(ServerLogRequest.body(logs: [Data(count: firstSize), Data(count: exactSecondSize)]).count == ServerLogRequest.maxBodyBytes)
    }

    @Test("로그 한 건은 직렬화한 크기가 1,000KiB 이하여야 한다")
    func isWithinLogLimit_checksBoundary() {
        #expect(ServerLogRequest.isWithinLogLimit(Data(count: 1_024_000)))
        #expect(ServerLogRequest.isWithinLogLimit(Data(count: 1_024_001)) == false)
    }
}
