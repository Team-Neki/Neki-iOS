//
//  ServerLogHttpClientTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct ServerLogHttpClientTests {
    @Test("토큰이 있으면 Bearer로 붙이고 본문을 그대로 POST /logs로 보낸다")
    func upload_withToken_sendsBearer() async throws {
        let session = URLSessionStub(statusCode: 200, body: #"{"resultCode":"D-0","message":"성공"}"#)
        let body = Data(#"{"platform":"IOS","logs":[]}"#.utf8)

        _ = await ServerLogHttpClient(session: session).upload(body: body, accessToken: "access-token")
        let request = try #require(session.lastRequest)

        #expect(request.httpMethod == "POST")
        #expect(request.url?.path.hasSuffix("/logs") == true)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-token")
        #expect(request.httpBody == body)
    }

    @Test("토큰이 없으면 Authorization 없이 보낸다")
    func upload_withoutToken_omitsAuthorization() async throws {
        let session = URLSessionStub(statusCode: 200, body: #"{"resultCode":"D-0","message":"성공"}"#)

        _ = await ServerLogHttpClient(session: session).upload(body: Data("{}".utf8), accessToken: nil)
        let request = try #require(session.lastRequest)

        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("응답의 상태 코드와 결과 코드를 그대로 돌려준다")
    func upload_returnsStatusAndResultCode() async {
        let tooLarge = URLSessionStub(statusCode: 413, body: #"{"resultCode":"D-16","message":"too large"}"#)
        let notJSON = URLSessionStub(statusCode: 502, body: "<html>Bad Gateway</html>")

        let tooLargeResult = await ServerLogHttpClient(session: tooLarge).upload(body: Data(), accessToken: nil)
        let notJSONResult = await ServerLogHttpClient(session: notJSON).upload(body: Data(), accessToken: nil)

        #expect(tooLargeResult == .responded(statusCode: 413, resultCode: "D-16"))
        #expect(notJSONResult == .responded(statusCode: 502, resultCode: nil))
    }

    @Test("타임아웃은 연결 실패가 아니라 응답 없음으로 돌려준다")
    func upload_whenTimedOut_returnsNoResponse() async {
        let session = URLSessionStub(error: URLError(.timedOut))

        let result = await ServerLogHttpClient(session: session).upload(body: Data(), accessToken: nil)

        #expect(result == .noResponse)
    }

    @Test("SDK가 오프라인으로 보는 연결 오류 6종은 연결 실패로 돌려준다", arguments: [
        URLError.Code.notConnectedToInternet,
        .networkConnectionLost,
        .cannotConnectToHost,
        .cannotFindHost,
        .appTransportSecurityRequiresSecureConnection,
        .badURL
    ])
    func upload_whenConnectionFails_returnsConnectionFailed(code: URLError.Code) async {
        let session = URLSessionStub(error: URLError(code))

        let result = await ServerLogHttpClient(session: session).upload(body: Data(), accessToken: nil)

        #expect(result == .connectionFailed)
    }
}


// MARK: - Helpers

private final class URLSessionStub: URLSessionProtocol, @unchecked Sendable {
    private let result: Result<(Data, Int), Error>
    private(set) var lastRequest: URLRequest?

    init(statusCode: Int, body: String) {
        self.result = .success((Data(body.utf8), statusCode))
    }

    init(error: Error) {
        self.result = .failure(error)
    }

    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        lastRequest = request
        let (data, statusCode) = try result.get()
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }

    /// 서버 로그 전송은 `data(for:delegate:)`만 씁니다.
    func bytes(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URLSession.AsyncBytes, URLResponse) {
        throw URLError(.unknown)
    }
}
