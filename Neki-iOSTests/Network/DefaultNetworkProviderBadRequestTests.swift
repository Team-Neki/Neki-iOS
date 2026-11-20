//
//  DefaultNetworkProviderBadRequestTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/20/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct DefaultNetworkProviderBadRequestTests {
    @Test("400 응답 본문의 결과 코드를 잘못된 요청 오류에 담아 넘긴다")
    func badRequest_carriesResultCode() async {
        let session = ScriptedURLSession(resultCode: { _ in "D-09" }) { _ in 400 }

        let resultCode = await badRequestResultCode(from: makeProvider(session: session))

        #expect(resultCode == "D-09")
    }

    @Test("결과 코드가 없는 400 응답은 결과 코드 없이 잘못된 요청 오류로 넘긴다")
    func badRequest_withoutResultCode() async {
        let session = ScriptedURLSession(resultCode: { _ in nil }) { _ in 400 }

        let resultCode = await badRequestResultCode(from: makeProvider(session: session))

        #expect(resultCode == nil)
    }
}

private extension DefaultNetworkProviderBadRequestTests {
    func makeProvider(session: ScriptedURLSession) -> DefaultNetworkProvider {
        DefaultNetworkProvider(
            session: session,
            credentialBroker: DefaultNetworkCredentialBroker()
        ) { _, _ in }
    }

    /// 요청이 잘못된 요청 오류로 끝나면 그 결과 코드를 돌려줍니다. 다르게 끝나면 테스트 실패로 남깁니다.
    func badRequestResultCode(from provider: DefaultNetworkProvider) async -> String? {
        do {
            let _: BaseResponseDTO<EmptyData> = try await provider.request(endpoint: BadRequestEndpointStub())
            Issue.record("400 응답이 오류 없이 끝났습니다")
        } catch NetworkError.badRequestError(let resultCode) {
            return resultCode
        } catch {
            Issue.record("400 응답이 잘못된 요청 오류가 아닌 \(error)로 끝났습니다")
        }
        return nil
    }
}

/// 토큰 없이 보내는 요청입니다. 응답은 세션 대역이 정합니다.
private struct BadRequestEndpointStub: Endpoint {
    let contentType: HTTPContentType = .json
    let baseURL = "https://example.com"
    let path = "/bad-request"
    let method: HTTPMethodType = .get
    let authorizationType: AuthorizationType = .none
    let body: (any Encodable)? = nil
}
