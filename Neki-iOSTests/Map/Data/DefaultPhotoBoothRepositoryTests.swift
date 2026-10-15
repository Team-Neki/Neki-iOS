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
            try await repository.searchCandidates(keyword: "홍대", type: .region, page: .zero, size: 10, origin: nil)
        }
    }

    @Test("따로 분류하지 않은 상태 코드로 실패한 검색은 기타 실패로 바꾼다")
    func searchCandidates_mapsUnexpectedStatusCodeToUnknownFailure() async {
        let repository = makeRepository(networkProvider: ThrowingNetworkProviderStub(error: NetworkError.networkFail))

        await #expect(throws: PhotoBoothSearchFailure.unknown) {
            try await repository.searchCandidates(keyword: "홍대", type: .region, page: .zero, size: 10, origin: nil)
        }
    }

    @Test("취소는 검색 실패로 바꾸지 않는다")
    func searchCandidates_keepsCancellation() async {
        let repository = makeRepository(networkProvider: ThrowingNetworkProviderStub(error: CancellationError()))

        await #expect(throws: CancellationError.self) {
            try await repository.searchCandidates(keyword: "홍대", type: .region, page: .zero, size: 10, origin: nil)
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

        let page = try await repository.searchCandidates(keyword: "강남", type: type, page: .zero, size: 20, origin: nil)

        #expect(await networkProvider.requestedPaths == [path])
        #expect(page.type == type)
        #expect(page.candidates.map(\.type) == [type])
    }

    @Test(
        "기준 좌표는 역·부스 자동완성에만 위도·경도로 담고 지역 자동완성에는 담지 않는다",
        arguments: zip([PhotoBoothSearchCandidateType.region, .subwayStation, .photoBooth], [false, true, true])
    )
    func searchCandidates_sendsOriginOnlyForStationsAndPhotoBooths(type: PhotoBoothSearchCandidateType, sendsOrigin: Bool) async throws {
        let emptyResponse = """
        {
          "resultCode": "D-0",
          "message": "OK",
          "data": { "items": [], "hasNext": false, "totalCount": 0, "filterGroup": {} }
        }
        """
        let networkProvider = RecordingNetworkProviderStub(responses: [
            "/search/completion/regions": emptyResponse,
            "/search/completion/stations": emptyResponse,
            "/search/completion/photo-booths": emptyResponse
        ])
        let repository = makeRepository(networkProvider: networkProvider)
        let origin = GeographicCoordinate(latitude: 37.4979, longitude: 127.0276)

        _ = try await repository.searchCandidates(keyword: "강남", type: type, page: .zero, size: 20, origin: origin)

        // 지역은 거리를 내려주지 않으므로 위치를 보내지 않습니다.
        let query = try #require(await networkProvider.requestedQueries.first ?? nil)
        #expect(query["latitude"] == (sendsOrigin ? "37.4979" : nil))
        #expect(query["longitude"] == (sendsOrigin ? "127.0276" : nil))
    }

    @Test("V2 즐겨찾기 목록과 같은 문자열 ID로 온 검색 결과 부스는 즐겨찾기 캐시를 따라 하트를 켠다")
    func readSearchResultPhotoBooths_marksPhotoBoothInV2FavoritesAsFavorite() async throws {
        let networkProvider = RecordingNetworkProviderStub(responses: [
            "/photo-booths/brand": """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": [{ "id": 1, "name": "포토이즘", "code": "PHOTOISM", "imageUrl": "" }]
            }
            """,
            "/v2/photo-booths/favorite": """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": {
                "items": [
                  {
                    "id": "source:PHOTOISM:1768232303",
                    "brandName": "포토이즘",
                    "branchName": "강남1호점",
                    "address": "서울 강남구 강남대로 396",
                    "longitude": 127.0276,
                    "latitude": 37.4979
                  }
                ]
              }
            }
            """,
            "/search/photo-booths": """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": {
                "items": [
                  {
                    "id": "source:PHOTOISM:1768232303",
                    "brandName": "포토이즘",
                    "brandCode": "PHOTOISM",
                    "branchName": "강남1호점",
                    "address": "서울 강남구 강남대로 396",
                    "latitude": 37.4979,
                    "longitude": 127.0276,
                    "distance": null,
                    "favorite": false
                  },
                  {
                    "id": "source:PHOTOISM:1768232304",
                    "brandName": "포토이즘",
                    "brandCode": "PHOTOISM",
                    "branchName": "강남2호점",
                    "address": "서울 강남구 테헤란로 101",
                    "latitude": 37.4985,
                    "longitude": 127.0281,
                    "distance": null,
                    "favorite": false
                  }
                ]
              }
            }
            """
        ])
        let repository = makeRepository(networkProvider: networkProvider)

        // 지도 화면이 나타나면 즐겨찾기 목록으로 캐시를 채우고, 그 뒤의 검색 결과 하트는 검색 응답 대신 이 캐시를 따릅니다.
        _ = try await repository.readFavoritePhotoBooths()
        let photoBooths = try await repository.readSearchResultPhotoBooths(
            keyword: "강남역 2호선",
            filterGroup: PhotoBoothSearchFilterGroup(),
            userCoordinate: nil
        )

        #expect(photoBooths.map(\.id) == ["source:PHOTOISM:1768232303", "source:PHOTOISM:1768232304"])
        #expect(photoBooths.map(\.isFavorite) == [true, false])
    }

    @Test("즐겨찾기 목록을 받기 전에는 지도 부스 응답의 favorite으로 하트를 켠다")
    func readPhotoBooths_beforeFavoritesLoaded_usesFavoriteOfResponse() async throws {
        let networkProvider = RecordingNetworkProviderStub(responses: [
            "/photo-booths/brand": """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": [{ "id": 1, "name": "포토이즘", "code": "PHOTOISM", "imageUrl": "" }]
            }
            """,
            "/v2/photo-booths/polygon": """
            {
              "resultCode": "D-0",
              "message": "OK",
              "data": {
                "items": [
                  {
                    "id": "source:PHOTOISM:1768232303",
                    "brandName": "포토이즘",
                    "branchName": "강남1호점",
                    "address": "서울 강남구 강남대로 396",
                    "longitude": 127.0276,
                    "latitude": 37.4979,
                    "favorite": true
                  },
                  {
                    "id": "source:PHOTOISM:1768232304",
                    "brandName": "포토이즘",
                    "branchName": "강남2호점",
                    "address": "서울 강남구 테헤란로 101",
                    "longitude": 127.0281,
                    "latitude": 37.4985,
                    "favorite": false
                  }
                ]
              }
            }
            """
        ])
        let repository = makeRepository(networkProvider: networkProvider)
        let bounds = GeographicBoundingBox(minLatitude: 37.49, minLongitude: 127.02, maxLatitude: 37.51, maxLongitude: 127.04)

        var photoBooths: [PhotoBooth] = []
        for try await chunk in await repository.readPhotoBooths(in: bounds) {
            photoBooths += chunk
        }

        #expect(photoBooths.map(\.id) == ["source:PHOTOISM:1768232303", "source:PHOTOISM:1768232304"])
        #expect(photoBooths.map(\.isFavorite) == [true, false])
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

/// 받은 요청의 경로와 쿼리를 기록하고, 경로마다 준비한 응답 JSON을 돌려주는 스텁입니다.
private actor RecordingNetworkProviderStub: NetworkProvider {
    private let responses: [String: String]
    private(set) var requestedPaths: [String] = []
    private(set) var requestedQueries: [[String: String]?] = []

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
        requestedQueries.append(endpoint.queryParameters)
        guard let response = responses[endpoint.path] else { throw NetworkError.networkFail }
        return try JSONDecoder().decode(BaseResponseDTO<T>.self, from: Data(response.utf8))
    }
}
