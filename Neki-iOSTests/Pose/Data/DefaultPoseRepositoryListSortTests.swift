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
        let repository = makeRepository(networkProvider)

        _ = try await repository.fetchPoseList(page: .zero, pageSize: 20, filter: PoseListFilter(), refresh: true)
        _ = try await repository.fetchScrappedPoseList(page: .zero, pageSize: 20, refresh: true)

        #expect(await networkProvider.requestedPaths == ["/poses", "/poses/scrap"])
        #expect(await networkProvider.requestedQueries == [
            ["page": "0", "size": "20", "sortOrder": "DESC"],
            ["page": "0", "size": "20", "sortOrder": "DESC"]
        ])
    }

    @Test("인원수와 관계 조건은 headCount와 relation으로 보내고, 썸은 SSUM으로 보낸다")
    func fetchPoseList_sendsPeopleCountAndRelation() async throws {
        let networkProvider = PoseListNetworkProviderStub()
        let repository = makeRepository(networkProvider)

        _ = try await repository.fetchPoseList(page: 1, pageSize: 20, filter: PoseListFilter(peopleCount: .duo, relation: .crush), refresh: true)
        _ = try await repository.fetchPoseList(page: .zero, pageSize: 20, filter: PoseListFilter(peopleCount: .overQuartet), refresh: true)

        #expect(await networkProvider.requestedQueries == [
            ["page": "1", "size": "20", "headCount": "TWO", "relation": "SSUM", "sortOrder": "DESC"],
            ["page": "0", "size": "20", "headCount": "FIVE_OR_MORE", "sortOrder": "DESC"]
        ])
    }

    @Test("응답의 전체 개수와 관계 값을 받고, 모르는 관계 값은 관계 없는 포즈로 둔다")
    func fetchPoseList_readsTotalCountAndRelation() async throws {
        let networkProvider = PoseListNetworkProviderStub(data: PoseListNetworkProviderStub.list(
            totalCount: 51,
            hasNext: true,
            relations: [(1, "FRIEND"), (2, "SSUM"), (3, "COLLEAGUE"), (4, nil)]
        ))
        let repository = makeRepository(networkProvider)

        let page = try await repository.fetchPoseList(page: .zero, pageSize: 20, filter: PoseListFilter(), refresh: true)

        #expect(page.totalCount == 51)
        #expect(page.hasNext)
        #expect(page.poses.map(\.relation) == [.friend, .crush, nil, nil])
    }

    @Test("전체 개수가 없는 응답도 목록은 그대로 받는다")
    func fetchPoseList_withoutTotalCount_keepsPoses() async throws {
        let networkProvider = PoseListNetworkProviderStub(data: PoseListNetworkProviderStub.list(totalCount: nil, hasNext: false, relations: [(9, nil)]))
        let repository = makeRepository(networkProvider)

        let page = try await repository.fetchPoseList(page: .zero, pageSize: 20, filter: PoseListFilter(), refresh: true)

        #expect(page.totalCount == nil)
        #expect(page.poses.map(\.id) == [9])
    }

    @Test("조건마다 받은 페이지를 따로 기억해, 다른 조건의 목록을 돌려주지 않는다")
    func fetchPoseList_cachesPagesPerFilter() async throws {
        let networkProvider = PoseListNetworkProviderStub(data: PoseListNetworkProviderStub.list(totalCount: 1, hasNext: false, relations: [(1, nil)]))
        let repository = makeRepository(networkProvider)
        let duo = PoseListFilter(peopleCount: .duo)

        _ = try await repository.fetchPoseList(page: .zero, pageSize: 20, filter: PoseListFilter(), refresh: false)
        _ = try await repository.fetchPoseList(page: .zero, pageSize: 20, filter: duo, refresh: false)
        let cachedPage = try await repository.fetchPoseList(page: .zero, pageSize: 20, filter: PoseListFilter(), refresh: false)

        #expect(await networkProvider.requestedQueries.map { $0?["headCount"] } == [nil, "TWO"])
        #expect(cachedPage.totalCount == 1)
    }
}

private extension DefaultPoseRepositoryListSortTests {
    func makeRepository(_ networkProvider: PoseListNetworkProviderStub) -> DefaultPoseRepository {
        withDependencies {
            $0.networkProvider = networkProvider
        } operation: {
            DefaultPoseRepository()
        }
    }
}

/// 받은 요청의 경로와 쿼리를 기록하고, 정해 둔 `data`로 포즈 목록 응답을 돌려주는 스텁입니다.
private actor PoseListNetworkProviderStub: NetworkProvider {
    private(set) var requestedPaths: [String] = []
    private(set) var requestedQueries: [[String: String]?] = []
    private let data: String

    init(data: String = #"{ "items": [], "hasNext": false }"#) {
        self.data = data
    }

    /// 포즈 목록 응답의 `data`입니다. 전체 개수가 nil이면 넣지 않고, 관계가 nil이면 null로 넣습니다.
    static func list(totalCount: Int?, hasNext: Bool, relations: [(id: Int, relation: String?)]) -> String {
        let items = relations.map { item in
            let relation = item.relation.map { "\"\($0)\"" } ?? "null"
            return """
            { "poseId": \(item.id), "headCount": "TWO", "imageUrl": "https://example.com/\(item.id).jpg", "scrap": false, "contentType": "image/jpeg", "createdAt": "2026-11-16T10:00:00", "relation": \(relation) }
            """
        }
        let totalCountField = totalCount.map { #""totalCount": \#($0), "# } ?? ""
        return "{ \(totalCountField)\"hasNext\": \(hasNext), \"items\": [\(items.joined(separator: ", "))] }"
    }

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
          "data": \(data)
        }
        """
        return try JSONDecoder().decode(BaseResponseDTO<T>.self, from: Data(response.utf8))
    }
}
