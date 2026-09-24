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

    @Test("따로 분류하지 않은 상태 코드로 실패한 검색은 네트워크 실패로 보지 않는다")
    func searchCandidates_keepsUnexpectedStatusCodeFailure() async {
        let repository = makeRepository(networkProvider: ThrowingNetworkProviderStub(error: NetworkError.networkFail))

        await #expect(throws: NetworkError.self) {
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
