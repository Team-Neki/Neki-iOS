//
//  ServerLogHttpClient.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/3/26.
//

import Foundation

/// 서버 로그 요청을 보내고 상태 코드와 결과 코드를 그대로 돌려줍니다(Amplitude-Swift `HttpClient`).
/// - Note: 공용 `NetworkProvider`는 2xx가 아니면 본문을 읽지 않고 413·403을 같은 오류로 묶습니다. 또 `.bearer`는 토큰 재발급과 전역 로그아웃으로 이어지므로, 서버 로그는 이 클라이언트로 따로 보냅니다.
struct ServerLogHttpClient {
    private let session: any URLSessionProtocol

    init(session: any URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    /// 토큰이 있으면 Bearer로 붙이고, 없으면 Authorization 없이 보냅니다.
    func upload(body: Data, accessToken: String?) async -> ServerLogUploadResult {
        do {
            var request = try ServerLogEndpoint(body: body).asURLRequest()
            if let accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await session.data(for: request, delegate: nil)
            guard let response = response as? HTTPURLResponse else { return .noResponse }
            let resultCode = try? JSONDecoder().decode(ResultCodeResponse.self, from: data).resultCode
            return .responded(statusCode: response.statusCode, resultCode: resultCode)
        } catch {
            return .noResponse
        }
    }
}

enum ServerLogUploadResult: Equatable, Sendable {
    /// 서버가 응답함
    case responded(statusCode: Int, resultCode: String?)
    /// 타임아웃·연결 실패처럼 응답을 받지 못함
    case noResponse
}

/// 행동 로그 적재(`POST /api/logs`)
struct ServerLogEndpoint: Endpoint {
    let body: (any Encodable)?

    init(body: Data) {
        self.body = body
    }

    var authorizationType: AuthorizationType { .none }
    var contentType: HTTPContentType { .custom("application/json") }
    var path: String { "logs" }
    var method: HTTPMethodType { .post }
}

private struct ResultCodeResponse: Decodable {
    let resultCode: String?
}
