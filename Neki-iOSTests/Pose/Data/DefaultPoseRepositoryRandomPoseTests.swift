//
//  DefaultPoseRepositoryRandomPoseTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/17/26.
//

import Dependencies
import Foundation
import Testing
@testable import Neki_iOS

struct DefaultPoseRepositoryRandomPoseTests {
    @Test("랜덤 포즈는 처음 받을 때 제외 ID 없이 요청하고, 다음부터 지금 포즈와 그 앞 3개를 제외 ID로 보낸다")
    func randomPose_sendsRecentPoseIDsAsExcludeIDs() async throws {
        let networkProvider = RandomPoseNetworkProviderStub()
        var requests = networkProvider.requests.makeAsyncIterator()
        let repository = makeRepository(networkProvider)

        // 서버가 1, 2, 3…을 차례로 주므로 겹치는 포즈가 없어, 포즈마다 요청이 한 번씩 나갑니다.
        _ = try await repository.initializeRandomPoseBuffer(peopleCount: .solo)
        for _ in 0..<4 {
            _ = try await repository.fetchNextRandomPose()
        }
        // 마지막으로 넘긴 뒤 다음 포즈를 미리 받는 요청까지 기다립니다.
        for _ in 0..<6 {
            _ = await requests.next()
        }

        let queries = await networkProvider.requestedQueries
        #expect(queries.map { $0?["headCount"] } == Array(repeating: "ONE", count: 6))
        #expect(queries.map { $0?["excludeIds"] } == [nil, "1", "1,2", "1,2,3", "1,2,3,4", "2,3,4,5"])
    }
}

private extension DefaultPoseRepositoryRandomPoseTests {
    func makeRepository(_ networkProvider: RandomPoseNetworkProviderStub) -> DefaultPoseRepository {
        withDependencies {
            $0.networkProvider = networkProvider
        } operation: {
            DefaultPoseRepository()
        }
    }
}

/// 랜덤 포즈 요청의 쿼리를 기록하고, 포즈 ID를 1부터 차례로 하나씩 돌려주는 스텁입니다.
private actor RandomPoseNetworkProviderStub: NetworkProvider {
    private(set) var requestedQueries: [[String: String]?] = []
    /// 요청을 받을 때마다 하나씩 흘려보냅니다.
    nonisolated let requests: AsyncStream<Void>
    private let requestContinuation: AsyncStream<Void>.Continuation
    private var nextPoseID = 1

    init() {
        (requests, requestContinuation) = AsyncStream<Void>.makeStream()
    }

    func requestVoid(endpoint: Endpoint) async throws {
        throw NetworkError.networkFail
    }

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        throw NetworkError.networkFail
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        requestedQueries.append(endpoint.queryParameters)
        let poseID = nextPoseID
        nextPoseID += 1
        requestContinuation.yield()
        let response = """
        {
          "resultCode": "D-0",
          "message": "OK",
          "data": { "poseId": \(poseID), "headCount": "ONE", "imageUrl": "https://example.com/\(poseID).jpg", "scrap": false, "contentType": "image/jpeg" }
        }
        """
        return try JSONDecoder().decode(BaseResponseDTO<T>.self, from: Data(response.utf8))
    }
}
