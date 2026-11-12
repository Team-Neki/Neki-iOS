//
//  DefaultPoseRepositoryListSortTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/11/26.
//

import Dependencies
import Foundation
import Testing
@testable import Neki_iOS

struct DefaultPoseRepositoryListSortTests {
    @Test("포즈 목록과 북마크 목록은 최신순(DESC)으로 요청한다")
    func fetchLists_requestLatestFirst() async throws {
        let networkProvider = PoseListNetworkProviderStub()
        let repository = withDependencies {
            $0.networkProvider = networkProvider
        } operation: {
            DefaultPoseRepository()
        }

        _ = try await repository.fetchPoseList(page: .zero, pageSize: 20, refresh: true)
        _ = try await repository.fetchScrappedPoseList(page: .zero, pageSize: 20, refresh: true)

        #expect(await networkProvider.requestedPaths == ["/poses", "/poses/scrap"])
        #expect(await networkProvider.requestedQueries == [
            ["page": "0", "size": "20", "sortOrder": "DESC"],
            ["page": "0", "size": "20", "sortOrder": "DESC"]
        ])
    }
}

/// 받은 요청의 경로와 쿼리를 기록하고 빈 포즈 목록을 돌려주는 스텁입니다.
private actor PoseListNetworkProviderStub: NetworkProvider {
    private(set) var requestedPaths: [String] = []
    private(set) var requestedQueries: [[String: String]?] = []

    func requestVoid(endpoint: Endpoint) async throws {
        throw NetworkError.networkFail
    }

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        throw NetworkError.networkFail
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        requestedPaths.append(endpoint.path)
        requestedQueries.append(endpoint.queryParameters)
        let response = """
        {
          "resultCode": "D-0",
          "message": "OK",
          "data": { "items": [], "hasNext": false }
        }
        """
        return try JSONDecoder().decode(BaseResponseDTO<T>.self, from: Data(response.utf8))
    }
}
