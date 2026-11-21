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

        // 서버가 제외 ID에 없는 가장 작은 ID를 주므로 1, 2, 3…이 차례로 와 겹치는 포즈가 없어, 포즈마다 요청이 한 번씩 나갑니다.
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

    @Test("남은 포즈가 없다는 응답을 받으면 화면을 닫을 때까지 다시 묻지 않고, 본 포즈를 본 지 오래된 순서로 보여 준다")
    func randomPose_stopsRequestingAfterNoMorePose() async throws {
        let networkProvider = RandomPoseNetworkProviderStub(poseCount: 3)
        let repository = makeRepository(networkProvider)

        var shownPoseIDs = [try await repository.initializeRandomPoseBuffer(peopleCount: .solo).id]
        for _ in 0..<8 {
            shownPoseIDs.append(try await repository.fetchNextRandomPose().id)
        }

        // 세 번째 포즈를 보여 준 뒤 다음 포즈를 미리 받다가 남은 포즈가 없다는 답을 한 번 받고, 그 뒤로는 묻지 않습니다.
        #expect(shownPoseIDs == [1, 2, 3, 1, 2, 3, 1, 2, 3])
        let queries = await networkProvider.requestedQueries
        #expect(queries.map { $0?["excludeIds"] } == [nil, "1", "1,2", "1,2,3"])
    }

    @Test("사진 정보 없음(D-04) 같은 다른 400을 받으면 멈추지 않고 다시 묻는다")
    func randomPose_keepsRequestingAfterOtherBadRequest() async throws {
        // 첫 포즈를 받은 뒤 다음 포즈를 미리 받는 두 번째 요청만 D-04로 실패합니다.
        let networkProvider = RandomPoseNetworkProviderStub(badRequestResultCodes: [2: "D-04"])
        var requests = networkProvider.requests.makeAsyncIterator()
        let repository = makeRepository(networkProvider)

        _ = try await repository.initializeRandomPoseBuffer(peopleCount: .solo)
        let nextPose = try await repository.fetchNextRandomPose()
        // 넘긴 뒤 다음 포즈를 미리 받는 요청까지 기다립니다.
        for _ in 0..<4 {
            _ = await requests.next()
        }

        // 실패한 요청 대신 앱에 남은 첫 포즈가 와서, 그 포즈를 빼고 다시 묻습니다.
        #expect(nextPose.id == 2)
        let queries = await networkProvider.requestedQueries
        #expect(queries.map { $0?["excludeIds"] } == [nil, "1", "1", "1,2"])
    }

    @Test("남은 포즈가 없어 멈춘 뒤 랜덤 포즈 화면을 다시 열면 처음부터 다시 묻는다")
    func randomPose_reopeningClearsNoMorePose() async throws {
        let networkProvider = RandomPoseNetworkProviderStub(poseCount: 1)
        var requests = networkProvider.requests.makeAsyncIterator()
        let repository = makeRepository(networkProvider)

        _ = try await repository.initializeRandomPoseBuffer(peopleCount: .solo)
        // 하나뿐인 포즈를 보고 있어 대신 보여 줄 포즈도 없으므로, 남은 포즈가 없다는 오류로 끝납니다.
        do {
            _ = try await repository.fetchNextRandomPose()
            Issue.record("남은 포즈가 없는데 다음 포즈를 받았습니다")
        } catch PoseRepositoryError.noMoreRandomPose {
        } catch {
            Issue.record("남은 포즈가 없다는 오류가 아닌 \(error)로 끝났습니다")
        }
        let reopenedPose = try await repository.initializeRandomPoseBuffer(peopleCount: .solo)
        // 다시 연 뒤 다음 포즈를 미리 받는 요청까지 기다립니다.
        for _ in 0..<4 {
            _ = await requests.next()
        }

        #expect(reopenedPose.id == 1)
        let queries = await networkProvider.requestedQueries
        #expect(queries.map { $0?["excludeIds"] } == [nil, "1", nil, "1"])
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

/// 랜덤 포즈 요청의 쿼리를 기록하고, 제외 ID에 없는 가장 작은 포즈 ID를 돌려주는 흉내 서버입니다.
/// 포즈 수를 정하면 남은 포즈가 없을 때 서버처럼 400 `D-09`를 던집니다.
private actor RandomPoseNetworkProviderStub: NetworkProvider {
    private(set) var requestedQueries: [[String: String]?] = []
    /// 요청을 받을 때마다 하나씩 흘려보냅니다.
    nonisolated let requests: AsyncStream<Void>
    private let requestContinuation: AsyncStream<Void>.Continuation
    /// 인원수의 포즈 수입니다. `nil`이면 포즈가 끝없이 있습니다.
    private let poseCount: Int?
    /// 몇 번째 요청(1부터)을 어떤 결과 코드의 400으로 실패시킬지입니다.
    private let badRequestResultCodes: [Int: String]

    init(poseCount: Int? = nil, badRequestResultCodes: [Int: String] = [:]) {
        (requests, requestContinuation) = AsyncStream<Void>.makeStream()
        self.poseCount = poseCount
        self.badRequestResultCodes = badRequestResultCodes
    }

    func requestVoid(endpoint: Endpoint) async throws {
        throw NetworkError.networkFail
    }

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        throw NetworkError.networkFail
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        requestedQueries.append(endpoint.queryParameters)
        requestContinuation.yield()
        if let resultCode = badRequestResultCodes[requestedQueries.count] {
            throw NetworkError.badRequestError(resultCode: resultCode)
        }

        let excludedIDs = Set((endpoint.queryParameters?["excludeIds"] ?? "").split(separator: ",").compactMap { Int($0) })
        guard let poseID = (1...).first(where: { excludedIDs.contains($0) == false }),
              poseID <= poseCount ?? .max
        else { throw NetworkError.badRequestError(resultCode: "D-09") }

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
