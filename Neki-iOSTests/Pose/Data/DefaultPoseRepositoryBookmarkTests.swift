//
//  DefaultPoseRepositoryBookmarkTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/17/26.
//

import Dependencies
import Foundation
import Testing
@testable import Neki_iOS

struct DefaultPoseRepositoryBookmarkTests {
    @Test("북마크 요청이 끝나기 전에 북마크 목록을 부르면, 북마크 요청이 끝난 뒤에 서버에서 받는다")
    func fetchScrappedPoseList_waitsForPendingScrapRequest() async throws {
        let (gate, openGate) = AsyncStream<Void>.makeStream()
        let (patchStarted, markPatchStarted) = AsyncStream<Void>.makeStream()
        let networkProvider = GatedScrapNetworkProviderStub(gate: gate, patchStarted: markPatchStarted)
        let repository = withDependencies {
            $0.networkProvider = networkProvider
        } operation: {
            DefaultPoseRepository()
        }
        _ = try await repository.fetchPoseList(page: .zero, pageSize: 20, filter: PoseListFilter(), refresh: true)

        let scrapTask = Task { try await repository.scrapPose(poseID: 1) }
        for await _ in patchStarted { break }
        let listTask = Task { try await repository.fetchScrappedPoseList(page: .zero, pageSize: 20, refresh: true) }
        // 목록 요청이 북마크 요청을 기다리지 않으면 이 사이에 서버로 갑니다.
        for _ in 0..<100 { await Task.yield() }
        openGate.yield()
        openGate.finish()
        try await scrapTask.value
        _ = try await listTask.value

        #expect(await networkProvider.log == ["GET /poses", "PATCH /poses/1/scrap", "PATCH 완료", "GET /poses/scrap"])
    }
}

/// 북마크 요청(PATCH)은 `gate`가 열릴 때까지 붙잡고, 받은 요청을 차례로 남기는 스텁입니다.
private actor GatedScrapNetworkProviderStub: NetworkProvider {
    private(set) var log: [String] = []
    private let gate: AsyncStream<Void>
    private let patchStarted: AsyncStream<Void>.Continuation

    init(gate: AsyncStream<Void>, patchStarted: AsyncStream<Void>.Continuation) {
        self.gate = gate
        self.patchStarted = patchStarted
    }

    func requestVoid(endpoint: Endpoint) async throws {
        throw NetworkError.networkFail
    }

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        try await respond(to: endpoint)
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        try await respond(to: endpoint)
    }

    private func respond<T: Decodable>(to endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        log.append("\(endpoint.method.rawValue) \(endpoint.path)")
        let data: String
        if endpoint.method == .patch {
            patchStarted.yield()
            for await _ in gate { break }
            log.append("PATCH 완료")
            data = "null"
        } else {
            data = """
            { "totalCount": 1, "hasNext": false, "items": [{ "poseId": 1, "headCount": "ONE", "imageUrl": "https://example.com/1.jpg", "scrap": false, "contentType": "image/jpeg", "createdAt": "2026-11-16T10:00:00", "relation": null }] }
            """
        }
        let response = """
        { "resultCode": "D-0", "message": "OK", "data": \(data) }
        """
        return try JSONDecoder().decode(BaseResponseDTO<T>.self, from: Data(response.utf8))
    }
}
