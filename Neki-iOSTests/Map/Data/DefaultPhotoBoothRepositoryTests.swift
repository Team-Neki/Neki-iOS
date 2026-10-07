//
//  DefaultPhotoBoothRepositoryTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 9/24/26.
//

import Dependencies
import Foundation
import Testing
@testable import Neki_iOS

struct DefaultPhotoBoothRepositoryTests {
    @Test("연결이 끊겨 실패한 검색은 네트워크 실패로 바꾼다")
    func searchCandidates_mapsConnectionLostToNetworkFailure() async {
        let networkProvider = ThrowingNetworkProviderStub(
            error: NetworkError.unknownError(URLError(.notConnectedToInternet))
        )
        let repository = makeRepository(networkProvider: networkProvider)

        await #expect(throws: PhotoBoothSearchFailure.network) {
            try await repository.searchCandidates(keyword: "홍대", type: .region, page: .zero, size: 10)
        }
    }

    @Test("따로 분류하지 않은 상태 코드로 실패한 검색은 기타 실패로 바꾼다")
    func searchCandidates_mapsUnexpectedStatusCodeToUnknownFailure() async {
        let repository = makeRepository(networkProvider: ThrowingNetworkProviderStub(error: NetworkError.networkFail))

        await #expect(throws: PhotoBoothSearchFailure.unknown) {
            try await repository.searchCandidates(keyword: "홍대", type: .region, page: .zero, size: 10)
        }
    }

    @Test("취소는 검색 실패로 바꾸지 않는다")
    func searchCandidates_keepsCancellation() async {
        let repository = makeRepository(networkProvider: ThrowingNetworkProviderStub(error: CancellationError()))

        await #expect(throws: CancellationError.self) {
            try await repository.searchCandidates(keyword: "홍대", type: .region, page: .zero, size: 10)
        }
    }

    @Test(
        "자동완성은 종류에 맞는 경로로 요청하고 응답을 그 종류의 후보로 바꾼다",
        arguments: zip(
            [PhotoBoothSearchCandidateType.region, .subwayStation, .photoBooth],
            ["/search/completion/regions", "/search/completion/stations", "/search/completion/photo-booths"]
        )
    )
    func searchCandidates_requestsCompletionPathOfType(type: PhotoBoothSearchCandidateType, path: String) async throws {
        let networkProvider = RecordingNetworkProviderStub(responses: [
            path: """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": {
                "items": [{ "keyword": "강남", "distanceKm": null }],
                "hasNext": false,
                "totalCount": 1,
                "filterGroup": {}
              }
            }
            """
        ])
        let repository = makeRepository(networkProvider: networkProvider)

        let page = try await repository.searchCandidates(keyword: "강남", type: type, page: .zero, size: 20)

        #expect(await networkProvider.requestedPaths == [path])
        #expect(page.type == type)
        #expect(page.candidates.map(\.type) == [type])
    }
}

private extension DefaultPhotoBoothRepositoryTests {
    func makeRepository(networkProvider: NetworkProvider) -> DefaultPhotoBoothRepository {
        withDependencies {
            $0.networkProvider = networkProvider
        } operation: {
            DefaultPhotoBoothRepository()
        }
    }
}

private actor ThrowingNetworkProviderStub: NetworkProvider {
    private let error: any Error

    init(error: any Error) {
        self.error = error
    }

    func requestVoid(endpoint: Endpoint) async throws {
        throw error
    }

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        throw error
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        throw error
    }
}

/// 받은 요청의 경로를 기록하고, 경로마다 준비한 응답 JSON을 돌려주는 스텁입니다.
private actor RecordingNetworkProviderStub: NetworkProvider {
    private let responses: [String: String]
    private(set) var requestedPaths: [String] = []

    init(responses: [String: String]) {
        self.responses = responses
    }

    func requestVoid(endpoint: Endpoint) async throws {
        throw NetworkError.networkFail
    }

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        throw NetworkError.networkFail
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        requestedPaths.append(endpoint.path)
        guard let response = responses[endpoint.path] else { throw NetworkError.networkFail }
        return try JSONDecoder().decode(BaseResponseDTO<T>.self, from: Data(response.utf8))
    }
}
