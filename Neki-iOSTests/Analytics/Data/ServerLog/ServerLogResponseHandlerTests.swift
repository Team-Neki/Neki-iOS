//
//  ServerLogResponseHandlerTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct ServerLogResponseHandlerTests {
    @Test("200 D-0은 보낸 로그를 지운다")
    func success_removesLogs() {
        let result = ServerLogUploadResult.responded(statusCode: 200, resultCode: "D-0")

        #expect(ServerLogResponseHandler.action(for: result, logCount: 10, sentWithAuthorization: true) == .remove)
    }

    @Test("413 D-16과 400 D-01은 반으로 나누고, 한 건이면 지운다", arguments: zip([413, 400], ["D-16", "D-01"]))
    func tooLargeOrInvalid_splitsUntilSingleLog(statusCode: Int, resultCode: String) {
        let result = ServerLogUploadResult.responded(statusCode: statusCode, resultCode: resultCode)

        #expect(ServerLogResponseHandler.action(for: result, logCount: 2, sentWithAuthorization: false) == .split)
        #expect(ServerLogResponseHandler.action(for: result, logCount: 1, sentWithAuthorization: false) == .drop)
    }

    @Test("401·403은 토큰을 붙였을 때만 토큰을 빼고 다시 보낸다", arguments: [401, 403])
    func unauthorized_retriesWithoutAuthorization(statusCode: Int) {
        let result = ServerLogUploadResult.responded(statusCode: statusCode, resultCode: nil)

        #expect(ServerLogResponseHandler.action(for: result, logCount: 3, sentWithAuthorization: true) == .retryWithoutAuthorization)
        #expect(ServerLogResponseHandler.action(for: result, logCount: 3, sentWithAuthorization: false) == .retryLater)
    }

    @Test("503 D-15와 그 밖의 응답, 응답 없음은 남겨 두고 나중에 다시 보낸다", arguments: [
        ServerLogUploadResult.responded(statusCode: 503, resultCode: "D-15"),
        .responded(statusCode: 500, resultCode: nil),
        .responded(statusCode: 404, resultCode: nil),
        .responded(statusCode: 429, resultCode: nil),
        .noResponse
    ])
    func transientFailures_retryLater(result: ServerLogUploadResult) {
        #expect(ServerLogResponseHandler.action(for: result, logCount: 5, sentWithAuthorization: false) == .retryLater)
    }

    @Test("연결 오류는 남겨 두고 네트워크 경로가 바뀔 때까지 기다린다")
    func connectionFailed_waitsForConnection() {
        #expect(ServerLogResponseHandler.action(for: .connectionFailed, logCount: 5, sentWithAuthorization: true) == .waitForConnection)
    }
}
