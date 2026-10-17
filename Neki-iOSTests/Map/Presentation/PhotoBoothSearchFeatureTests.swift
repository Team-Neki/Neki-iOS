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
        #expect(store.state.rows.map(\.type) == [.region, .region, .photoBooth, .photoBooth, .photoBooth])
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
        #expect(store.state.contentState.isResults)
    }

    @Test("후보 목록은 다시 그리는 데 필요한 값과 검색마다 다른 요청 차수를 함께 담는다")
    func contentState_whenResultsArrive_carriesListValuesAndGeneration() async {
        let store = makeStore(pages: [.region: [makeRegionPage(count: 2, hasNext: false)]])

        await submitSearch(on: store)
        guard case let .results(rows, keyword, firstGeneration, _) = store.state.contentState else {
            Issue.record("후보 목록 상태가 아닙니다")
            return
        }
        #expect(rows == store.state.rows)
        #expect(keyword == "강남")

        // 같은 검색어로 다시 검색해도 새 목록은 직전 목록과 구분되어야 스크롤이 처음부터 시작합니다.
        await submitSearch(on: store)
        guard case let .results(_, _, secondGeneration, _) = store.state.contentState else {
            Issue.record("다시 검색한 뒤 후보 목록 상태가 아닙니다")
            return
        }
        #expect(secondGeneration != firstGeneration)
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

        #expect(store.state.rows.map(\.type) == [.region, .subwayStation, .photoBooth])
    }

    @Test("종류 안에서는 서버가 내려준 순서와 거리를 그대로 노출한다")
    func rows_keepServerOrderAndDistanceWithinType() async {
        let store = makeStore(pages: [
            .photoBooth: [
                makePhotoBoothPage(distances: [500, 100], hasNext: true),
                makePhotoBoothPage(distances: [300, 50], firstIndex: 2, hasNext: false)
            ]
        ])

        await submitSearch(on: store)
        await store.send(.fetchNextCandidatePage)
        await settle(store)

        // 서버가 일치도를 먼저 따져 세우므로 거리가 뒤섞여 보여도 클라이언트가 다시 세우지 않습니다.
        #expect(store.state.rows.map(\.keyword) == [
            "포토이즘 강남1호점",
            "포토이즘 강남2호점",
            "포토이즘 강남3호점",
            "포토이즘 강남4호점"
        ])
        #expect(store.state.rows.map(\.distance?.meters) == [500, 100, 300, 50])
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
        #expect(store.state.rows.map(\.type) == [.subwayStation])
    }

    @Test("거리 기준 좌표는 검색 도중 바뀌지 않고 다음 검색을 요청할 때 그 시점의 위치로 다시 세운다")
    func distanceOrigin_staysPinnedUntilNextSearchRequest() async {
        let store = makeStore(pages: [.photoBooth: [makePhotoBoothPage(count: 1, hasNext: false)]])

        // 첫 위치를 받기 전에 검색을 요청하면 기본 좌표로 기준을 세웁니다.
        await submitSearch(on: store)
        #expect(store.state.distanceOrigin == PhotoBoothSearchFeature.Constants.defaultDistanceOrigin)

        // 검색 도중 좌표가 도착해도 이 검색의 기준은 그대로입니다.
        let arrivedCoordinate = GeographicCoordinate(latitude: 37.4000, longitude: 127.0276)
        await store.send(.setUserCoordinate(arrivedCoordinate))
        #expect(store.state.distanceOrigin == PhotoBoothSearchFeature.Constants.defaultDistanceOrigin)

        // 다음 검색을 요청하면 그 시점의 위치로 기준을 다시 세웁니다.
        await submitSearch(on: store)
        #expect(store.state.distanceOrigin == arrivedCoordinate)
    }

    @Test("위치를 모른 채 검색하면 기본 좌표로 잰 거리를 후보에 표기하지 않고, 위치를 받은 뒤 다음 검색부터 표기한다")
    func isDistanceVisible_whenUserCoordinateWasUnknownAtSearch_hidesDistanceUntilNextSearch() async {
        let store = makeStore(pages: [.photoBooth: [makePhotoBoothPage(distances: [500], hasNext: false)]])

        // 위치를 모른 채 검색하면 서버에는 기본 좌표를 넘기되, 그 좌표로 잰 거리는 사용자 위치에서 잰 거리가 아니라 표기하지 않습니다.
        await submitSearch(on: store)
        #expect(store.state.distanceOrigin == PhotoBoothSearchFeature.Constants.defaultDistanceOrigin)
        #expect(store.state.contentState.isDistanceVisible == false)

        // 검색 도중 위치를 받아도 이 검색의 거리는 여전히 기본 좌표로 잰 값이라 표기하지 않습니다.
        await store.send(.setUserCoordinate(GeographicCoordinate(latitude: 37.4000, longitude: 127.0276)))
        #expect(store.state.contentState.isDistanceVisible == false)

        // 다음 검색부터는 받은 위치로 거리를 재므로 표기합니다.
        await submitSearch(on: store)
        #expect(store.state.contentState.isDistanceVisible == true)
    }

    @Test("첫 화면을 채우는 후보 요청 동안 로딩을 노출한다")
    func isAwaitingFirstCandidates_whileFirstCandidatePageIsInFlight_showsLoading() async {
        let store = makeStore(pages: [.region: [makeRegionPage(count: 2, hasNext: false)]])

        await store.send(.binding(.set(\.searchText, "강남")))
        // 제출하면 같은 액션 안에서 첫 페이지 요청까지 시작하므로, 응답을 흘려보내기 전 상태를 봅니다.
        await store.send(.submitSearch)

        #expect(store.state.rows.isEmpty)
        #expect(store.state.isAwaitingFirstCandidates)
        // 첫 후보가 올 때까지 본문은 안내를 그대로 두고, 로딩은 본문과 따로 알립니다.
        #expect(store.state.contentState == .guide)

        await settle(store)

        #expect(store.state.isAwaitingFirstCandidates == false)
        #expect(store.state.contentState.isResults)
    }

    @Test("새 검색을 제출하면 첫 후보가 올 때까지 직전 목록을 그대로 노출한다")
    func contentState_whileAwaitingNewSearch_keepsPreviousResults() async {
        let store = makeStore(pages: [.region: [makeRegionPage(count: 2, hasNext: false)]])
        await submitSearch(on: store)
        let previousContent = store.state.contentState

        await submitPendingSearch(on: store, keyword: "홍대")

        #expect(store.state.isAwaitingFirstCandidates)
        #expect(store.state.rows.isEmpty)
        // 검색어와 요청 차수까지 직전 그대로라 뷰는 같은 목록을 같은 스크롤 위치에서 이어서 그립니다.
        #expect(store.state.contentState == previousContent)

        // 붙잡아 둔 요청을 취소해 테스트를 끝냅니다.
        await store.send(.dismissSearch)
        await store.finish()
    }

    @Test("첫 후보를 기다리는 동안 노출 중인 직전 목록의 후보를 골라도 지도로 넘기지 않는다")
    func didSelectCandidate_whileAwaitingNewSearch_ignoresPreviousCandidate() async {
        let delegates = LockIsolated<[PhotoBoothSearchFeature.Action.Delegate]>([])
        let store = makeStore(pages: [.region: [makeRegionPage(count: 2, hasNext: false)]], delegates: delegates)
        await submitSearch(on: store)
        guard let previousCandidate = store.state.rows.first else {
            Issue.record("후보가 없어 선택 동작을 확인할 수 없습니다")
            return
        }

        await submitPendingSearch(on: store, keyword: "홍대")
        await store.send(.didSelectCandidate(previousCandidate))

        #expect(delegates.value.isEmpty)

        // 붙잡아 둔 요청을 취소해 테스트를 끝냅니다.
        await store.send(.dismissSearch)
        await store.finish()
    }

    @Test("새 검색이 실패하면 직전 목록 대신 실패를 노출한다")
    func contentState_whenNewSearchFails_showsFailureInsteadOfPreviousResults() async {
        let store = makeStore(pages: [.region: [makeRegionPage(count: 2, hasNext: false)]])
        await submitSearch(on: store)

        store.dependencies.photoBoothClient.searchCandidates = { _, _, _, _ in
            throw NetworkError.responseDecodingError
        }
        await store.send(.binding(.set(\.searchText, "홍대")))
        await store.send(.submitSearch)
        await settle(store)

        #expect(store.state.isAwaitingFirstCandidates == false)
        #expect(store.state.contentState == .failure(.unknown))
    }

    @Test("검색을 닫았다가 다시 검색하면 직전 결과가 아니라 안내를 유지한다")
    func contentState_afterDismissSearch_keepsGuideWhileAwaiting() async {
        let store = makeStore(pages: [.region: [makeRegionPage(count: 2, hasNext: false)]])
        await submitSearch(on: store)
        await store.send(.dismissSearch)

        await submitPendingSearch(on: store, keyword: "홍대")

        #expect(store.state.isAwaitingFirstCandidates)
        #expect(store.state.contentState == .guide)

        // 붙잡아 둔 요청을 취소해 테스트를 끝냅니다.
        await store.send(.dismissSearch)
        await store.finish()
    }

    @Test("목록을 이어붙이는 후보 요청은 로딩으로 목록을 덮지 않는다")
    func isAwaitingFirstCandidates_whileAppendingCandidatePage_keepsList() async {
        let store = makeStore(pages: [
            .region: [
                makeRegionPage(count: 20, hasNext: true),
                makeRegionPage(count: 20, firstIndex: 20, hasNext: false)
            ]
        ])

        await submitSearch(on: store)
        await store.send(.fetchNextCandidatePage)

        #expect(store.state.isFetching)
        #expect(store.state.isAwaitingFirstCandidates == false)
    }

    @Test("후보를 고르면 직접 조회하지 않고 고른 후보와 검색어를 지도로 넘긴다")
    func didSelectCandidate_delegatesCandidateWithQuery() async {
        let delegates = LockIsolated<[PhotoBoothSearchFeature.Action.Delegate]>([])
        let store = makeStore(pages: [.region: [makeRegionPage(count: 1, hasNext: false)]], delegates: delegates)

        await submitSearch(on: store)
        guard let candidate = store.state.rows.first else {
            Issue.record("후보가 없어 선택 동작을 확인할 수 없습니다")
            return
        }

        await store.send(.didSelectCandidate(candidate))
        await settle(store)

        // 부스 목록은 지도가 조회하므로, 검색 화면을 닫으면 비워질 검색어와 기준 좌표, 거리 표기 여부를 함께 넘깁니다.
        #expect(delegates.value == [.didSelectCandidate(
            candidate: candidate,
            query: PhotoBoothSearchQuery(rawValue: "강남"),
            distanceOrigin: PhotoBoothSearchFeature.Constants.defaultDistanceOrigin,
            isDistanceVisible: false
        )])
    }

    @Test("후보를 고르면 검색을 요청한 시점에 고정한 기준 좌표와 거리 표기 여부를 지도로 넘긴다")
    func didSelectCandidate_delegatesPinnedDistanceOrigin() async {
        let delegates = LockIsolated<[PhotoBoothSearchFeature.Action.Delegate]>([])
        let store = makeStore(pages: [.region: [makeRegionPage(count: 1, hasNext: false)]], delegates: delegates)

        let searchTimeCoordinate = GeographicCoordinate(latitude: 37.4979, longitude: 127.0276)
        await store.send(.setUserCoordinate(searchTimeCoordinate))
        await submitSearch(on: store)

        // 검색 도중 위치가 갱신되어도 이 검색의 기준은 바뀌지 않습니다.
        await store.send(.setUserCoordinate(.init(latitude: 37.4000, longitude: 127.0276)))
        guard let candidate = store.state.rows.first else {
            Issue.record("후보가 없어 선택 동작을 확인할 수 없습니다")
            return
        }

        await store.send(.didSelectCandidate(candidate))
        await settle(store)

        // 후보 목록과 결과 목록의 거리가 어긋나지 않도록 지도도 같은 기준으로 조회하게 합니다.
        // 검색할 때 위치를 알았으므로 결과에도 거리를 표기합니다.
        guard case let .didSelectCandidate(_, _, distanceOrigin, isDistanceVisible) = delegates.value.first else {
            Issue.record("후보 선택을 지도로 넘기지 않았습니다")
            return
        }
        #expect(distanceOrigin == searchTimeCoordinate)
        #expect(isDistanceVisible)
    }

    @Test("후보 페이지는 모두 검색을 요청한 시점에 고정한 기준 좌표로 요청한다")
    func fetchNextCandidatePage_sendsPinnedDistanceOrigin() async {
        let log = SearchRequestLog()
        let store = makeStore(log: log, pages: [
            .subwayStation: [
                makeStationPage(count: 20, hasNext: true),
                makeStationPage(count: 1, firstIndex: 20, hasNext: false)
            ]
        ])

        let searchTimeCoordinate = GeographicCoordinate(latitude: 37.4979, longitude: 127.0276)
        await store.send(.setUserCoordinate(searchTimeCoordinate))
        await submitSearch(on: store)

        // 검색 도중 위치가 갱신되어도 다음 페이지는 같은 기준으로 요청해야 서버가 거리로 세운 순서가 페이지 사이에서 이어집니다.
        await store.send(.setUserCoordinate(.init(latitude: 37.4000, longitude: 127.0276)))
        await store.send(.fetchNextCandidatePage)
        await settle(store)

        #expect(await log.requests == [
            .init(type: .region, page: 0),
            .init(type: .subwayStation, page: 0),
            .init(type: .subwayStation, page: 1)
        ])
        #expect(await log.origins == [searchTimeCoordinate, searchTimeCoordinate, searchTimeCoordinate])
    }

    @Test("위치를 모르면 기본 좌표를 후보 요청의 기준으로 넘긴다")
    func fetchNextCandidatePage_whenUserCoordinateIsUnknown_sendsDefaultOrigin() async {
        let log = SearchRequestLog()
        let store = makeStore(log: log, pages: [.region: [makeRegionPage(count: 1, hasNext: false)]])

        await submitSearch(on: store)

        // 위치를 몰라도 서버에는 기본 좌표를 기준으로 넘깁니다. 그 좌표로 잰 거리는 화면에 표기하지 않습니다.
        #expect(await log.origins == [PhotoBoothSearchFeature.Constants.defaultDistanceOrigin])
    }

    @Test("위치를 모르면 기본 좌표를 기준 좌표로 넘기고, 결과에 거리를 표기하지 않도록 지도에 알린다")
    func didSelectCandidate_whenUserCoordinateIsUnknown_delegatesDefaultOrigin() async {
        let delegates = LockIsolated<[PhotoBoothSearchFeature.Action.Delegate]>([])
        let store = makeStore(pages: [.region: [makeRegionPage(count: 1, hasNext: false)]], delegates: delegates)

        await submitSearch(on: store)
        guard let candidate = store.state.rows.first else {
            Issue.record("후보가 없어 선택 동작을 확인할 수 없습니다")
            return
        }

        await store.send(.didSelectCandidate(candidate))
        await settle(store)

        // 위치를 몰라도 서버에는 기본 좌표를 기준으로 넘기되, 그 좌표로 잰 거리는 결과에도 표기하지 않습니다.
        guard case let .didSelectCandidate(_, _, distanceOrigin, isDistanceVisible) = delegates.value.first else {
            Issue.record("후보 선택을 지도로 넘기지 않았습니다")
            return
        }
        #expect(distanceOrigin == PhotoBoothSearchFeature.Constants.defaultDistanceOrigin)
        #expect(isDistanceVisible == false)
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
        #expect(store.state.contentState.isResults)

        await store.send(.binding(.set(\.searchText, "")))
        await settle(store)

        #expect(store.state.mode == .searching)
        #expect(store.state.query?.rawValue == "강남")
        #expect(store.state.contentState.isResults)
        #expect(store.state.rows.count == 2)
    }
}


// MARK: - Helpers

private extension PhotoBoothSearchFeature.State.ContentState {
    /// 목록 내용과 상관없이 후보 목록을 노출하는 상태인지 여부입니다.
    var isResults: Bool {
        guard case .results = self else { return false }
        return true
    }

    /// 후보 목록에 거리를 표기하는지 여부입니다. 후보 목록을 노출하는 상태가 아니면 `nil`입니다.
    var isDistanceVisible: Bool? {
        guard case let .results(_, _, _, isDistanceVisible) = self else { return nil }
        return isDistanceVisible
    }
}


private struct SearchRequest: Equatable {
    let type: PhotoBoothSearchCandidateType
    let page: Int
}

private actor SearchRequestLog {
    private(set) var requests: [SearchRequest] = []
    /// 요청마다 넘긴 거리 기준 좌표입니다. ``requests``와 같은 순서입니다.
    private(set) var origins: [GeographicCoordinate?] = []

    func record(type: PhotoBoothSearchCandidateType, page: Int, origin: GeographicCoordinate?) {
        requests.append(SearchRequest(type: type, page: page))
        origins.append(origin)
    }
}

private extension PhotoBoothSearchFeatureTests {
    func makeStore(
        log: SearchRequestLog = SearchRequestLog(),
        pages: [PhotoBoothSearchCandidateType: [PhotoBoothSearchCandidatePage]] = [:],
        candidateError: (any Error)? = nil,
        /// 응답을 붙잡아 후보 페이지 요청이 진행 중인 상태를 만들 때 씁니다.
        candidateResponseDelay: Duration? = nil,
        /// 검색 화면이 상위 화면(지도)으로 넘긴 알림을 받은 순서대로 담습니다.
        delegates: LockIsolated<[PhotoBoothSearchFeature.Action.Delegate]> = .init([])
    ) -> TestStoreOf<PhotoBoothSearchFeature> {
        let store = TestStore(initialState: PhotoBoothSearchFeature.State()) {
            CombineReducers {
                PhotoBoothSearchFeature()
                Reduce<PhotoBoothSearchFeature.State, PhotoBoothSearchFeature.Action> { _, action in
                    if case let .delegate(delegate) = action {
                        delegates.withValue { $0.append(delegate) }
                    }
                    return .none
                }
            }
        } withDependencies: {
            $0.photoBoothClient.searchCandidates = { _, type, page, origin in
                await log.record(type: type, page: page, origin: origin)
                if let candidateResponseDelay { try await Task.sleep(for: candidateResponseDelay) }
                if let candidateError { throw candidateError }
                guard let typePages = pages[type], page < typePages.count else {
                    return PhotoBoothSearchCandidatePage(type: type, candidates: [], hasNext: false)
                }
                return typePages[page]
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

    /// 응답을 붙잡아 둔 채 새 검색을 제출해, 첫 후보를 기다리는 상태로 만듭니다.
    func submitPendingSearch(on store: TestStoreOf<PhotoBoothSearchFeature>, keyword: String) async {
        store.dependencies.photoBoothClient.searchCandidates = { _, type, _, _ in
            try await Task.sleep(for: .seconds(60))
            return PhotoBoothSearchCandidatePage(type: type, candidates: [], hasNext: false)
        }
        await store.send(.binding(.set(\.searchText, keyword)))
        await store.send(.submitSearch)
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
                PhotoBoothSearchCandidate(type: .region, keyword: "서울특별시 강남구 역삼\(index + 1)동", filterGroup: .init())
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
                PhotoBoothSearchCandidate(type: .subwayStation, keyword: "강남역 \(index + 2)호선", filterGroup: .init())
            },
            hasNext: hasNext
        )
    }

    /// 거리만 달리한 부스 후보 페이지입니다. 서버 순서를 그대로 지키는지 확인하는 데 씁니다.
    ///
    /// 페이지끼리 식별자가 겹치지 않도록 시작 번호를 받습니다.
    func makePhotoBoothPage(
        distances: [Int],
        firstIndex: Int = 0,
        hasNext: Bool
    ) -> PhotoBoothSearchCandidatePage {
        PhotoBoothSearchCandidatePage(
            type: .photoBooth,
            candidates: distances.enumerated().map { offset, meters in
                PhotoBoothSearchCandidate(
                    type: .photoBooth,
                    keyword: "포토이즘 강남\(firstIndex + offset + 1)호점",
                    filterGroup: .init(),
                    distance: GeographicDistance(meters: meters)
                )
            },
            hasNext: hasNext
        )
    }

    func makePhotoBoothPage(count: Int, hasNext: Bool) -> PhotoBoothSearchCandidatePage {
        PhotoBoothSearchCandidatePage(
            type: .photoBooth,
            candidates: (0..<count).map { index in
                PhotoBoothSearchCandidate(type: .photoBooth, keyword: "포토이즘 강남\(index + 1)호점", filterGroup: .init())
            },
            hasNext: hasNext
        )
    }
}
