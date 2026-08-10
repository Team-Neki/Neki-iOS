//
//  DefaultArchiveRepositoryTests.swift
//  Neki-iOSTests
//
//  Created by SwainYun on 7/3/26.
//

import Dependencies
import Foundation
import Testing
@testable import Neki_iOS

struct DefaultArchiveRepositoryTests {
    @Test("페이지 응답을 순서대로 병합하고 중복 ID를 제거한다")
    func fetchNextPhotos_mergesUniquePhotosInServerOrder() async throws {
        let networkProvider = ArchiveNetworkProviderStub(responses: [
            photoListResponse(ids: [1, 2], hasNext: true, totalCount: 3),
            photoListResponse(ids: [2, 3], hasNext: false, totalCount: 3)
        ])
        let repository = makeRepository(networkProvider: networkProvider)

        let firstSnapshot = try await repository.refreshPhotos(
            scope: .all,
            size: 2,
            sortOrder: .descending
        )
        let finalSnapshot = try await repository.fetchNextPhotos(
            scope: .all,
            size: 2,
            sortOrder: .descending
        )
        let requestCount = await networkProvider.requestCount

        #expect(firstSnapshot.photos.map(\.id) == [1, 2])
        #expect(finalSnapshot.photos.map(\.id) == [1, 2, 3])
        #expect(finalSnapshot.hasNext == false)
        #expect(requestCount == 2)
    }

    @Test("같은 scope의 동일 페이지 동시 요청을 한 번만 수행한다")
    func refreshPhotos_coalescesDuplicateRequest() async throws {
        let networkProvider = ArchiveNetworkProviderStub(
            responses: [photoListResponse(ids: [1], hasNext: false, totalCount: 1)],
            delay: .milliseconds(50)
        )
        let repository = makeRepository(networkProvider: networkProvider)

        async let first = repository.refreshPhotos(scope: .all, size: 20, sortOrder: .descending)
        async let second = repository.refreshPhotos(scope: .all, size: 20, sortOrder: .descending)
        let snapshots = try await [first, second]
        let requestCount = await networkProvider.requestCount

        #expect(snapshots.allSatisfy { $0.photos.map(\.id) == [1] })
        #expect(requestCount == 1)
    }

    @Test("즐겨찾기 변경은 캐시된 단일 엔티티에 즉시 반영한다")
    func toggleFavorite_updatesNormalizedEntity() async throws {
        let networkProvider = ArchiveNetworkProviderStub(responses: [
            photoListResponse(ids: [1], hasNext: false, totalCount: 1),
            emptyResponse()
        ])
        let repository = makeRepository(networkProvider: networkProvider)

        _ = try await repository.refreshPhotos(scope: .all, size: 20, sortOrder: .descending)
        try await repository.toggleFavorite(photoID: 1, request: true)
        let snapshot = try await repository.refreshPhotos(scope: .all, size: 20, sortOrder: .descending)
        let requestCount = await networkProvider.requestCount

        #expect(snapshot.photos.first?.isFavorite == true)
        #expect(requestCount == 2)
    }

    @Test("정렬 조건이 바뀌면 해당 scope만 첫 페이지부터 다시 조회한다")
    func refreshPhotos_whenSortChanges_resetsScope() async throws {
        let networkProvider = ArchiveNetworkProviderStub(responses: [
            photoListResponse(ids: [2, 1], hasNext: false, totalCount: 2),
            photoListResponse(ids: [1, 2], hasNext: false, totalCount: 2)
        ])
        let repository = makeRepository(networkProvider: networkProvider)

        _ = try await repository.refreshPhotos(scope: .all, size: 20, sortOrder: .descending)
        let snapshot = try await repository.refreshPhotos(scope: .all, size: 20, sortOrder: .ascending)
        let requestCount = await networkProvider.requestCount

        #expect(snapshot.photos.map(\.id) == [1, 2])
        #expect(requestCount == 2)
    }

    @Test("한 scope를 초기화해도 다른 scope가 참조하는 사진은 유지한다")
    func refreshPhotos_whenSharedPhotoExists_preservesOtherScope() async throws {
        let networkProvider = ArchiveNetworkProviderStub(responses: [
            photoListResponse(ids: [1], hasNext: false, totalCount: 1),
            photoListResponse(ids: [1], hasNext: false, totalCount: 1),
            photoListResponse(ids: [2], hasNext: false, totalCount: 1)
        ])
        let repository = makeRepository(networkProvider: networkProvider)

        _ = try await repository.refreshPhotos(scope: .all, size: 20, sortOrder: .descending)
        _ = try await repository.refreshPhotos(scope: .favorites, size: 20, sortOrder: .descending)
        _ = try await repository.refreshPhotos(scope: .all, size: 20, sortOrder: .ascending)
        let favoriteSnapshot = try await repository.refreshPhotos(
            scope: .favorites,
            size: 20,
            sortOrder: .descending
        )
        let requestCount = await networkProvider.requestCount

        #expect(favoriteSnapshot.photos.map(\.id) == [1])
        #expect(favoriteSnapshot.photos.allSatisfy(\.isFavorite))
        #expect(requestCount == 3)
    }
}

private extension DefaultArchiveRepositoryTests {
    func makeRepository(networkProvider: NetworkProvider) -> DefaultArchiveRepository {
        withDependencies {
            $0.networkProvider = networkProvider
        } operation: {
            DefaultArchiveRepository()
        }
    }

    func photoListResponse(
        ids: [Int],
        hasNext: Bool,
        totalCount: Int
    ) -> Data {
        let items = ids.map {
            """
            {
              "photoId": \($0),
              "imageUrl": "https://example.com/\($0).jpg",
              "folderId": null,
              "favorite": false,
              "contentType": "image/jpeg",
              "createdAt": "2026-07-03T00:00:00Z",
              "memo": null,
              "width": 1080,
              "height": 1440
            }
            """
        }.joined(separator: ",")

        return Data(
            """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": {
                "items": [\(items)],
                "hasNext": \(hasNext),
                "totalCount": \(totalCount)
              }
            }
            """.utf8
        )
    }

    func emptyResponse() -> Data {
        Data(
            """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": {}
            }
            """.utf8
        )
    }
}

private actor ArchiveNetworkProviderStub: NetworkProvider {
    private var responses: [Data]
    private let delay: Duration?
    private(set) var requestCount = 0

    init(responses: [Data], delay: Duration? = nil) {
        self.responses = responses
        self.delay = delay
    }

    func requestVoid(endpoint: Endpoint) async throws {}

    func request(endpoint: Endpoint) async throws -> BaseResponseDTO<EmptyData> {
        try await decodeNextResponse()
    }

    func request<T: Decodable>(endpoint: Endpoint) async throws -> BaseResponseDTO<T> {
        try await decodeNextResponse()
    }

    private func decodeNextResponse<T: Decodable>() async throws -> BaseResponseDTO<T> {
        if let delay { try await Task.sleep(for: delay) }
        guard responses.isEmpty == false else { throw NetworkError.responseError }
        requestCount += 1
        return try JSONDecoder().decode(BaseResponseDTO<T>.self, from: responses.removeFirst())
    }
}
