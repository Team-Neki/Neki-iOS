//
//  PhotoBoothSearchFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 8/31/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct PhotoBoothSearchFeatureTests {
    @Test("앞선 종류가 남아 있으면 다음 페이지도 같은 종류를 요청한다")
    func fetchNextCandidatePage_whenTypeHasNextPage_staysOnSameType() async {
        let log = SearchRequestLog()
        let store = makeStore(log: log, pages: [
            .region: [
                makeRegionPage(count: 20, hasNext: true),
                makeRegionPage(count: 20, firstIndex: 20, hasNext: true)
            ]
        ])

        await submitSearch(on: store)
        await store.send(.fetchNextCandidatePage)
        await store.finish()

        #expect(await log.requests == [.init(type: .region, page: 0), .init(type: .region, page: 1)])
    }

    @Test("앞선 종류를 모두 소진해야 다음 종류로 넘어간다")
    func fetchNextCandidatePage_whenTypeExhausted_movesToNextType() async {
        let log = SearchRequestLog()
        let store = makeStore(log: log, pages: [
            .region: [makeRegionPage(count: 2, hasNext: false)],
            .subwayStation: [makeStationPage(count: 1, hasNext: false)]
        ])

        await submitSearch(on: store)
        #expect(await log.requests == [.init(type: .region, page: 0)])

        await store.send(.fetchNextCandidatePage)
        await store.finish()

        #expect(await log.requests == [.init(type: .region, page: 0), .init(type: .subwayStation, page: 0)])
    }

    @Test("앞선 종류에 결과가 있어도 빈 페이지가 오면 다음 종류까지 이어 부른다")
    func fetchNextCandidatePage_whenNextTypeReturnsEmptyPage_keepsChaining() async {
        let log = SearchRequestLog()
        let store = makeStore(log: log, pages: [
            .region: [makeRegionPage(count: 2, hasNext: false)],
            .subwayStation: [makeStationPage(count: 0, hasNext: false)],
            .photoBooth: [makePhotoBoothPage(count: 3, hasNext: false)]
        ])

        await submitSearch(on: store)
        #expect(await log.requests == [.init(type: .region, page: 0)])

        await store.send(.fetchNextCandidatePage)
        await settle(store)

        // 빈 페이지는 새 셀을 만들지 않아 스크롤 트리거가 생기지 않으므로 스스로 다음 종류까지 이어 부릅니다.
        #expect(await log.requests == [
            .init(type: .region, page: 0),
            .init(type: .subwayStation, page: 0),
            .init(type: .photoBooth, page: 0)
        ])
        #expect(store.state.rows.map(\.candidate.type) == [.region, .region, .photoBooth, .photoBooth, .photoBooth])
    }

    @Test("이미 요청 중이면 트리거가 여러 번 와도 한 번만 요청한다")
    func fetchNextCandidatePage_whileFetching_requestsOnlyOnce() async {
        let log = SearchRequestLog()
        let store = makeStore(
            log: log,
            pages: [.region: [makeRegionPage(count: 20, hasNext: true)]],
            // 응답을 붙잡아 두 번째 트리거가 진행 중인 요청과 겹치게 합니다.
            candidateResponseDelay: .seconds(60)
        )

        await store.send(.binding(.set(\.searchText, "강남")))
        await store.send(.submitSearch)
        await store.receive(\.fetchNextCandidatePage)

        // 미리 부르는 셀과 마지막 셀이 함께 나타나 트리거가 두 번 발생한 상황입니다.
        await store.send(.fetchNextCandidatePage)
        await store.send(.fetchNextCandidatePage)

        #expect(store.state.isFetching)
        #expect(await log.requests == [.init(type: .region, page: 0)])

        // 붙잡아 둔 요청을 취소해 테스트를 끝냅니다.
        await store.send(.dismissSearch)
        await store.finish()
    }

    @Test("모든 종류에 결과가 없으면 전체 검색 결과 없음을 노출한다")
    func contentState_whenEveryTypeIsEmpty_showsNoResult() async {
        let log = SearchRequestLog()
        let store = makeStore(log: log, pages: [
            .region: [makeRegionPage(count: 0, hasNext: false)],
            .subwayStation: [makeStationPage(count: 0, hasNext: false)],
            .photoBooth: [makePhotoBoothPage(count: 0, hasNext: false)]
        ])

        await submitSearch(on: store)

        // 목록이 비어 있으면 스크롤 트리거가 없으므로 스스로 다음 종류까지 이어 부릅니다.
        #expect(await log.requests == [
            .init(type: .region, page: 0),
            .init(type: .subwayStation, page: 0),
            .init(type: .photoBooth, page: 0)
        ])
        #expect(store.state.contentState == .noResult)
    }

    @Test("일부 종류에만 결과가 있으면 결과 없음이 아니다")
    func contentState_whenAnyTypeHasResult_showsResults() async {
        let log = SearchRequestLog()
        let store = makeStore(log: log, pages: [
            .region: [makeRegionPage(count: 0, hasNext: false)],
            .subwayStation: [makeStationPage(count: 1, hasNext: false)]
        ])

        await submitSearch(on: store)

        #expect(await log.requests == [.init(type: .region, page: 0), .init(type: .subwayStation, page: 0)])
        #expect(store.state.contentState == .results)
    }

    @Test("검색 후보를 지역 → 지하철역 → 포토부스 순서로 이어붙인다")
    func rows_followPolicyOrder() async {
        let store = makeStore(pages: [
            .region: [makeRegionPage(count: 1, hasNext: false)],
            .subwayStation: [makeStationPage(count: 1, hasNext: false)],
            .photoBooth: [makePhotoBoothPage(count: 1, hasNext: false)]
        ])

        await submitSearch(on: store)
        await exhaustAllTypes(on: store)

        #expect(store.state.rows.map(\.candidate.type) == [.region, .subwayStation, .photoBooth])
    }

    @Test("거리는 위치에 동의하고 좌표가 있는 후보에만 노출한다")
    func rows_showDistanceOnlyWhenCoordinateIsAvailable() async {
        let store = makeStore(pages: [
            .region: [makeRegionPage(count: 1, hasNext: false)],
            .subwayStation: [makeStationPage(count: 1, hasNext: false)],
            .photoBooth: [makePhotoBoothPage(count: 1, hasNext: false)]
        ])

        await store.send(.setUserCoordinate(.init(latitude: 37.4979, longitude: 127.0276)))
        await submitSearch(on: store)
        await exhaustAllTypes(on: store)

        let distancesByType = Dictionary(
            uniqueKeysWithValues: store.state.rows.map { ($0.candidate.type, $0.distance) }
        )
        // 지역은 정책상 거리를 노출하지 않고, 지하철역은 검색 응답에 좌표가 없어 계산할 수 없습니다.
        #expect(distancesByType[.region] == .some(nil))
        #expect(distancesByType[.subwayStation] == .some(nil))
        #expect(distancesByType[.photoBooth]??.isMultiple(of: 1) == true)
    }

    @Test("위치에 동의하지 않으면 거리를 노출하지 않는다")
    func rows_hideDistanceWhenLocationIsNotAuthorized() async {
        let store = makeStore(pages: [
            .region: [makeRegionPage(count: 0, hasNext: false)],
            .subwayStation: [makeStationPage(count: 0, hasNext: false)],
            .photoBooth: [makePhotoBoothPage(count: 1, hasNext: false)]
        ])

        await submitSearch(on: store)

        #expect(store.state.userCoordinate == nil)
        #expect(store.state.rows.allSatisfy { $0.distance == nil })
    }

    @Test("종류 순서를 지키면서 좌표가 있는 후보를 가까운 순으로 세운다")
    func rows_sortCandidatesWithCoordinateByDistance() async {
        let store = makeStore(pages: [
            .region: [makeRegionPage(count: 1, hasNext: false)],
            .subwayStation: [makeStationPage(count: 1, hasNext: false)],
            .photoBooth: [makePhotoBoothPage(coordinates: [
                .init(latitude: 37.6000, longitude: 127.0276),
                .init(latitude: 37.5000, longitude: 127.0276),
                .init(latitude: 37.5500, longitude: 127.0276)
            ])]
        ])

        await store.send(.setUserCoordinate(.init(latitude: 37.4979, longitude: 127.0276)))
        await submitSearch(on: store)
        await exhaustAllTypes(on: store)

        // 후보 검색은 기준 위치를 받지 않아 서버 순서가 거리순이 아니므로 클라이언트가 다시 세웁니다.
        // 종류 사이의 순서는 정책이라 거리로 뒤섞지 않습니다.
        #expect(store.state.rows.map(\.id) == [
            "region:1168000000",
            "station:강남:2호선",
            "photoBooth:1",
            "photoBooth:2",
            "photoBooth:0"
        ])
    }

    @Test("다음 페이지는 그 페이지 안에서만 세워 이미 보여준 후보 사이로 끼어들지 않는다")
    func rows_sortWithinEachPageWithoutReorderingShownCandidates() async {
        let store = makeStore(pages: [
            .photoBooth: [
                makePhotoBoothPage(
                    coordinates: [
                        .init(latitude: 37.6000, longitude: 127.0276),
                        .init(latitude: 37.5000, longitude: 127.0276)
                    ],
                    firstID: 0,
                    hasNext: true
                ),
                makePhotoBoothPage(
                    coordinates: [
                        .init(latitude: 37.5500, longitude: 127.0276),
                        .init(latitude: 37.4980, longitude: 127.0276)
                    ],
                    firstID: 2,
                    hasNext: false
                )
            ]
        ])

        await store.send(.setUserCoordinate(.init(latitude: 37.4979, longitude: 127.0276)))
        await submitSearch(on: store)
        await store.send(.fetchNextCandidatePage)
        await settle(store)

        // 두 번째 페이지에 가장 가까운 후보(photoBooth:3)가 있어도 첫 페이지 위로 올라오지 않습니다.
        #expect(store.state.rows.map(\.id) == [
            "photoBooth:1",
            "photoBooth:0",
            "photoBooth:3",
            "photoBooth:2"
        ])
    }

    @Test("페이지에 걸쳐 같은 후보가 내려와도 목록에 한 번만 담는다")
    func rows_dropDuplicatedCandidatesAcrossPages() async {
        let store = makeStore(pages: [
            .region: [
                makeRegionPage(count: 2, hasNext: true),
                // 페이징 도중 서버 데이터가 바뀌어 앞 페이지의 후보가 다시 내려온 상황입니다.
                makeRegionPage(count: 3, hasNext: false)
            ]
        ])

        await submitSearch(on: store)
        await store.send(.fetchNextCandidatePage)
        await settle(store)

        let ids = store.state.rows.map(\.id)
        #expect(ids.count == 3)
        #expect(Set(ids).count == ids.count)
    }

    @Test("새로 담을 후보가 없는데 다음이 있다는 응답은 소진으로 보고 다음 종류로 넘어간다")
    func candidatePageResponse_whenPageAddsNothingButHasNext_movesToNextType() async {
        let log = SearchRequestLog()
        let store = makeStore(log: log, pages: [
            // 다음 페이지가 있다고 하면서 후보를 주지 않는 응답입니다.
            // 그대로 믿으면 같은 종류만 끝없이 되묻게 되므로 소진으로 판정해야 합니다.
            .region: [makeRegionPage(count: 0, hasNext: true)],
            .subwayStation: [makeStationPage(count: 1, hasNext: false)]
        ])

        await submitSearch(on: store)

        #expect(await log.requests == [.init(type: .region, page: 0), .init(type: .subwayStation, page: 0)])
        #expect(store.state.rows.map(\.candidate.type) == [.subwayStation])
    }

    @Test("거리 기준은 검색을 시작한 시점의 위치로 고정한다")
    func rows_keepDistanceOriginFixedAtSearchTime() async {
        let store = makeStore(pages: [
            .photoBooth: [makePhotoBoothPage(coordinates: [.init(latitude: 37.5000, longitude: 127.0276)])]
        ])

        await store.send(.setUserCoordinate(.init(latitude: 37.4979, longitude: 127.0276)))
        await submitSearch(on: store)
        let distanceAtSearchTime = store.state.rows.first?.distance

        // 검색 도중 위치가 갱신되어도 이미 보고 있는 목록의 거리는 흔들리지 않습니다.
        await store.send(.setUserCoordinate(.init(latitude: 37.4000, longitude: 127.0276)))

        #expect(distanceAtSearchTime != nil)
        #expect(store.state.rows.first?.distance == distanceAtSearchTime)
    }

    @Test("위치를 모르면 서버가 내려준 순서를 그대로 지킨다")
    func rows_keepServerOrderWhenUserCoordinateIsUnknown() async {
        let store = makeStore(pages: [
            .photoBooth: [makePhotoBoothPage(coordinates: [
                .init(latitude: 37.6000, longitude: 127.0276),
                .init(latitude: 37.5000, longitude: 127.0276),
                .init(latitude: 37.5500, longitude: 127.0276)
            ])]
        ])

        await submitSearch(on: store)

        #expect(store.state.userCoordinate == nil)
        #expect(store.state.rows.map(\.id) == ["photoBooth:0", "photoBooth:1", "photoBooth:2"])
    }

    @Test("첫 화면을 채우는 후보 요청 동안 로딩을 노출한다")
    func isLoading_whileFirstCandidatePageIsInFlight_showsLoading() async {
        let store = makeStore(pages: [.region: [makeRegionPage(count: 2, hasNext: false)]])

        await store.send(.binding(.set(\.searchText, "강남")))
        await store.send(.submitSearch)
        // 응답까지 흘려보내면 로딩이 이미 내려가므로 요청을 시작한 지점까지만 진행합니다.
        await store.receive(\.fetchNextCandidatePage)

        #expect(store.state.rows.isEmpty)
        #expect(store.state.isLoading)

        await settle(store)

        #expect(store.state.isLoading == false)
    }

    @Test("목록을 이어붙이는 후보 요청은 로딩으로 목록을 덮지 않는다")
    func isLoading_whileAppendingCandidatePage_keepsList() async {
        let store = makeStore(pages: [
            .region: [
                makeRegionPage(count: 20, hasNext: true),
                makeRegionPage(count: 20, firstIndex: 20, hasNext: false)
            ]
        ])

        await submitSearch(on: store)
        await store.send(.fetchNextCandidatePage)

        #expect(store.state.isFetching)
        #expect(store.state.isLoading == false)
    }

    @Test("후보를 선택해 부스를 조회하는 동안 로딩을 노출한다")
    func isLoading_whileSearchResultIsInFlight_showsLoading() async {
        let store = makeStore(
            pages: [.region: [makeRegionPage(count: 1, hasNext: false)]],
            searchResult: { [] }
        )

        await submitSearch(on: store)
        guard let candidate = store.state.rows.first?.candidate else {
            Issue.record("후보가 없어 선택 동작을 확인할 수 없습니다")
            return
        }

        await store.send(.didSelectCandidate(candidate))
        #expect(store.state.isLoading)

        await settle(store)

        #expect(store.state.isLoading == false)
    }

    @Test("후보를 고르면 부스 목록과 필터를 함께 조회한다")
    func didSelectCandidate_fetchesPhotoBoothsAndBrandFiltersTogether() async {
        let filterLog = SearchFilterRequestLog()
        let brand = PhotoBoothBrand(id: 1, name: "포토이즘", englishName: "PHOTOISM", imageURL: nil)
        let store = makeStore(
            pages: [.region: [makeRegionPage(count: 1, hasNext: false)]],
            brandFilters: [PhotoBoothSearchBrandFilter(brand: brand, count: 9)],
            filterLog: filterLog
        )

        await submitSearch(on: store)
        guard let candidate = store.state.rows.first?.candidate else {
            Issue.record("후보가 없어 선택 동작을 확인할 수 없습니다")
            return
        }

        await store.send(.didSelectCandidate(candidate))
        await store.receive(\.delegate)

        // 요청 body가 같아 고른 후보 그대로 필터도 함께 조회합니다.
        #expect(await filterLog.candidates == [candidate])
    }

    @Test("부스 조회가 진행 중이면 다른 후보를 골라도 다시 조회하지 않는다")
    func didSelectCandidate_whileFetchingSearchResult_ignoresSecondSelection() async {
        let requestLog = SearchResultRequestLog()
        let store = makeStore(pages: [.region: [makeRegionPage(count: 2, hasNext: false)]])
        store.dependencies.photoBoothClient.fetchSearchPhotoBooths = { candidate, _ in
            await requestLog.record(candidate)
            // 응답을 붙잡아 두 번째 선택이 조회 중인 상태와 겹치게 합니다.
            try await Task.sleep(for: .seconds(60))
            return []
        }

        await submitSearch(on: store)
        let candidates = store.state.rows.map(\.candidate)
        guard let firstCandidate = candidates.first,
              let secondCandidate = candidates.last,
              firstCandidate != secondCandidate
        else {
            Issue.record("후보가 둘 이상이어야 중복 선택을 확인할 수 있습니다")
            return
        }

        await store.send(.didSelectCandidate(firstCandidate))
        await requestLog.waitForFirstRequest()
        #expect(store.state.isFetchingSearchResult)

        // 로딩이 화면을 덮기 전에 두 셀이 한 번에 눌린 상황입니다.
        await store.send(.didSelectCandidate(secondCandidate))

        // 붙잡아 둔 조회를 취소해 시작된 요청이 모두 기록된 상태로 만듭니다.
        await store.send(.dismissSearch)
        await store.finish()

        // 먼저 고른 후보의 조회만 나가고 나중에 눌린 셀은 무시합니다.
        #expect(await requestLog.candidates == [firstCandidate])
    }

    @Test("필터 조회가 실패하면 부스 목록도 내보내지 않고 실패를 알린다")
    func didSelectCandidate_whenBrandFilterFails_surfacesFailure() async {
        struct BrandFilterError: Error {}
        let store = makeStore(pages: [.region: [makeRegionPage(count: 1, hasNext: false)]])
        store.dependencies.photoBoothClient.fetchSearchBrandFilters = { _ in throw BrandFilterError() }

        await submitSearch(on: store)
        guard let candidate = store.state.rows.first?.candidate else {
            Issue.record("후보가 없어 선택 동작을 확인할 수 없습니다")
            return
        }

        await store.send(.didSelectCandidate(candidate))
        await settle(store)

        #expect(store.state.isLoading == false)
        #expect(store.state.toast != nil)
    }

    @Test("부스 조회가 실패하면 로딩을 내리고 후보 목록을 지킨 채 실패를 알린다")
    func isLoading_whenSearchResultFails_hidesLoading() async {
        struct SearchResultError: Error {}
        let store = makeStore(
            pages: [.region: [makeRegionPage(count: 1, hasNext: false)]],
            searchResult: { throw SearchResultError() }
        )

        await submitSearch(on: store)
        guard let candidate = store.state.rows.first?.candidate else {
            Issue.record("후보가 없어 선택 동작을 확인할 수 없습니다")
            return
        }

        await store.send(.didSelectCandidate(candidate))
        await settle(store)

        #expect(store.state.isLoading == false)
        #expect(store.state.toast != nil)
        // 실패 알림이 이미 쌓아 둔 후보 목록을 덮지 않습니다.
        #expect(store.state.contentState == .results)
    }

    @Test("새 검색을 제출하면 진행 중이던 부스 조회 로딩을 내린다")
    func isLoading_whenSearchRestarts_hidesSearchResultLoading() async {
        let store = makeStore(pages: [.region: [makeRegionPage(count: 1, hasNext: false)]])

        await submitSearch(on: store)
        guard let candidate = store.state.rows.first?.candidate else {
            Issue.record("후보가 없어 선택 동작을 확인할 수 없습니다")
            return
        }

        await store.send(.didSelectCandidate(candidate))
        #expect(store.state.isFetchingSearchResult)

        await store.send(.beginSearch(PhotoBoothSearchQuery(rawValue: "홍대")))

        #expect(store.state.isFetchingSearchResult == false)
    }

    @Test("빈 검색어는 요청하지 않는다")
    func submitSearch_whenKeywordIsEmpty_doesNotRequest() async {
        let log = SearchRequestLog()
        let store = makeStore(log: log)

        await store.send(.binding(.set(\.searchText, "")))
        await store.send(.submitSearch)
        await store.finish()

        #expect(await log.requests.isEmpty)
        #expect(store.state.mode == .inactive)
    }

    @Test("공백뿐인 검색어는 서버가 판정하므로 그대로 요청하고 실패를 노출한다")
    func submitSearch_whenKeywordIsBlank_requestsAndSurfacesServerFailure() async {
        let log = SearchRequestLog()
        // 서버는 공백뿐인 검색어를 `D-01`로 거절하고, 그 응답에는 `data`가 없어 오류로 올라옵니다.
        let store = makeStore(log: log, candidateError: NetworkError.responseDecodingError)

        await store.send(.binding(.set(\.searchText, "   ")))
        await store.send(.submitSearch)
        await settle(store)

        #expect(store.state.mode == .searching)
        // 클라이언트가 다듬지 않고 입력한 그대로 넘깁니다.
        #expect(store.state.query?.rawValue == "   ")
        #expect(await log.requests == [.init(type: .region, page: 0)])
        #expect(store.state.contentState == .failure(.unknown))
    }

    @Test("검색어를 모두 지워도 직전 검색 결과를 유지한다")
    func binding_whenSearchTextBecomesEmpty_keepsResults() async {
        let store = makeStore(pages: [.region: [makeRegionPage(count: 2, hasNext: false)]])

        await submitSearch(on: store)
        #expect(store.state.contentState == .results)

        await store.send(.binding(.set(\.searchText, "")))
        await settle(store)

        #expect(store.state.mode == .searching)
        #expect(store.state.query?.rawValue == "강남")
        #expect(store.state.contentState == .results)
        #expect(store.state.rows.count == 2)
    }
}


// MARK: - Helpers

private struct SearchRequest: Equatable {
    let type: PhotoBoothSearchCandidateType
    let page: Int
}

private actor SearchRequestLog {
    private(set) var requests: [SearchRequest] = []

    func record(type: PhotoBoothSearchCandidateType, page: Int) {
        requests.append(SearchRequest(type: type, page: page))
    }
}

/// 후보를 고른 뒤 나가는 부스 조회의 호출 기록입니다.
///
/// 조회가 실제로 시작된 시점을 기다릴 수 있어, 조회 중 상태에서만 성립하는 동작을 흔들림 없이 확인합니다.
private actor SearchResultRequestLog {
    private(set) var candidates: [PhotoBoothSearchCandidate] = []
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func record(_ candidate: PhotoBoothSearchCandidate) {
        candidates.append(candidate)
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }

    /// 첫 조회가 실제로 시작될 때까지 기다립니다.
    func waitForFirstRequest() async {
        guard candidates.isEmpty else { return }
        await withCheckedContinuation { continuations.append($0) }
    }
}

/// 부스 목록과 함께 나가야 하는 필터 조회의 호출 기록입니다.
private actor SearchFilterRequestLog {
    private(set) var candidates: [PhotoBoothSearchCandidate] = []

    func record(_ candidate: PhotoBoothSearchCandidate) {
        candidates.append(candidate)
    }
}

private extension PhotoBoothSearchFeatureTests {
    func makeStore(
        log: SearchRequestLog = SearchRequestLog(),
        pages: [PhotoBoothSearchCandidateType: [PhotoBoothSearchCandidatePage]] = [:],
        candidateError: (any Error)? = nil,
        /// 응답을 붙잡아 후보 페이지 요청이 진행 중인 상태를 만들 때 씁니다.
        candidateResponseDelay: Duration? = nil,
        searchResult: @escaping @Sendable () async throws -> [PhotoBooth] = { [] },
        brandFilters: [PhotoBoothSearchBrandFilter] = [],
        filterLog: SearchFilterRequestLog = SearchFilterRequestLog()
    ) -> TestStoreOf<PhotoBoothSearchFeature> {
        let store = TestStore(initialState: PhotoBoothSearchFeature.State()) {
            PhotoBoothSearchFeature()
        } withDependencies: {
            $0.photoBoothClient.searchCandidates = { _, type, page in
                await log.record(type: type, page: page)
                if let candidateResponseDelay { try await Task.sleep(for: candidateResponseDelay) }
                if let candidateError { throw candidateError }
                guard let typePages = pages[type], page < typePages.count else {
                    return PhotoBoothSearchCandidatePage(type: type, candidates: [], hasNext: false)
                }
                return typePages[page]
            }
            $0.photoBoothClient.fetchSearchPhotoBooths = { _, _ in try await searchResult() }
            $0.photoBoothClient.fetchSearchBrandFilters = { candidate in
                await filterLog.record(candidate)
                return brandFilters
            }
        }
        store.exhaustivity = .off
        return store
    }

    /// 검색어를 제출하고 이어지는 효과가 모두 끝날 때까지 기다립니다.
    func submitSearch(on store: TestStoreOf<PhotoBoothSearchFeature>) async {
        await store.send(.binding(.set(\.searchText, "강남")))
        await store.send(.submitSearch)
        await settle(store)
    }

    /// 스크롤로 다음 페이지를 부르는 동작을 대신해 남은 종류를 모두 불러옵니다.
    func exhaustAllTypes(on store: TestStoreOf<PhotoBoothSearchFeature>) async {
        while store.state.pendingType != nil {
            await store.send(.fetchNextCandidatePage)
            await settle(store)
        }
    }

    /// 진행 중인 효과가 끝나고 그 결과가 `store.state`에 반영될 때까지 기다립니다.
    ///
    /// `TestStore.state`는 `send`로 보낸 액션까지만 반영한 스냅샷이라
    /// `finish()`만으로는 효과가 되돌려준 액션의 상태 변화가 보이지 않습니다.
    /// 받은 액션을 흘려보내 스냅샷을 최신 상태로 맞춥니다.
    func settle(_ store: TestStoreOf<PhotoBoothSearchFeature>) async {
        await store.finish()
        await store.skipReceivedActions(strict: false)
    }

    /// 지역 후보 페이지입니다.
    ///
    /// 페이지끼리 식별자가 겹치지 않도록 시작 번호를 받습니다.
    func makeRegionPage(count: Int, firstIndex: Int = 0, hasNext: Bool) -> PhotoBoothSearchCandidatePage {
        PhotoBoothSearchCandidatePage(
            type: .region,
            candidates: (firstIndex..<(firstIndex + count)).map { index in
                .region(.init(code: "116800000\(index)", name: "강남구", fullName: "서울특별시 강남구"))
            },
            hasNext: hasNext
        )
    }

    /// 지하철역 후보 페이지입니다.
    ///
    /// 페이지끼리 식별자가 겹치지 않도록 시작 번호를 받습니다.
    func makeStationPage(count: Int, firstIndex: Int = 0, hasNext: Bool) -> PhotoBoothSearchCandidatePage {
        PhotoBoothSearchCandidatePage(
            type: .subwayStation,
            candidates: (firstIndex..<(firstIndex + count)).map { index in
                .subwayStation(.init(name: "강남", lineName: "\(index + 2)호선"))
            },
            hasNext: hasNext
        )
    }

    /// 좌표만 달리한 부스 후보 페이지입니다. 거리 정렬을 확인하는 데 씁니다.
    ///
    /// 페이지끼리 식별자가 겹치지 않도록 시작 번호를 받습니다.
    func makePhotoBoothPage(
        coordinates: [GeographicCoordinate],
        firstID: Int = 0,
        hasNext: Bool = false
    ) -> PhotoBoothSearchCandidatePage {
        PhotoBoothSearchCandidatePage(
            type: .photoBooth,
            candidates: coordinates.enumerated().map { index, coordinate in
                .photoBooth(
                    PhotoBooth(
                        id: firstID + index,
                        brand: PhotoBoothBrand(id: 1, name: "포토이즘", englishName: "PHOTOISM", imageURL: nil),
                        name: "강남\(firstID + index + 1)호점",
                        coordinate: coordinate,
                        address: "서울 강남구 강남대로102길 16"
                    )
                )
            },
            hasNext: hasNext
        )
    }

    func makePhotoBoothPage(count: Int, hasNext: Bool) -> PhotoBoothSearchCandidatePage {
        PhotoBoothSearchCandidatePage(
            type: .photoBooth,
            candidates: (0..<count).map { index in
                .photoBooth(
                    PhotoBooth(
                        id: index,
                        brand: PhotoBoothBrand(id: 1, name: "포토이즘", englishName: "PHOTOISM", imageURL: nil),
                        name: "강남\(index + 1)호점",
                        coordinate: .init(latitude: 37.5021077, longitude: 127.0271830),
                        address: "서울 강남구 강남대로102길 16"
                    )
                )
            },
            hasNext: hasNext
        )
    }
}
