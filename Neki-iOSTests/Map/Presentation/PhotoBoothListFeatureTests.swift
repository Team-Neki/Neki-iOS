//
//  PhotoBoothListFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 9/8/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct PhotoBoothListFeatureTests {
    @Test("브랜드 칩을 누르면 브랜드 필터 시트를 연다")
    func didTapSearchResultBrandFilterChip_presentsSheet() async {
        let store = makeStore()

        await store.send(.didTapSearchResultBrandFilterChip) {
            $0.isSearchResultBrandFilterSheetPresented = true
        }
    }

    @Test("시트의 확인을 누르면 브랜드 필터 시트를 닫는다")
    func dismissSearchResultBrandFilterSheet_hidesSheet() async {
        var state = PhotoBoothListFeature.State()
        state.isSearchResultBrandFilterSheetPresented = true
        let store = makeStore(initialState: state)

        await store.send(.dismissSearchResultBrandFilterSheet) {
            $0.isSearchResultBrandFilterSheetPresented = false
        }
    }

    @Test("검색 결과를 보는 동안에는 결과에 있는 브랜드만 필터 칩으로 노출한다")
    func selectableBrands_whenSearchResultBrandFiltersSet_narrowsToSearchResult() async {
        let photoism = makeBrand(id: 1, name: "포토이즘")
        let life4cut = makeBrand(id: 2, name: "인생네컷")
        var state = PhotoBoothListFeature.State()
        state.brands = [photoism, life4cut]
        let store = makeStore(initialState: state)
        let brandFilters = [PhotoBoothSearchBrandFilter(brand: life4cut, count: 3)]

        await store.send(.setSearchResultBrandFilters(brandFilters)) {
            $0.searchResultBrandFilters = brandFilters
        }
        #expect(store.state.selectableBrands == [life4cut])

        await store.send(.setSearchResultBrandFilters(nil)) {
            $0.searchResultBrandFilters = nil
        }
        #expect(store.state.selectableBrands == [photoism, life4cut])
    }

    @Test("브랜드 필터 칩을 누를 때마다 그 브랜드의 선택이 토글된다")
    func selectFilterOption_togglesSelection() async {
        let brand = makeBrand(id: 1, name: "포토이즘")
        let store = makeStore()

        await store.send(.selectFilterOption(brand)) {
            $0.filteredBrands = [brand]
        }
        await store.send(.selectFilterOption(brand)) {
            $0.filteredBrands = []
        }
    }

    @Test("브랜드 필터 칩을 누르면 선택·해제, 선택한 수, 브랜드 이름과 함께 브랜드 ID를 남긴다")
    func selectFilterOption_logsBrandFilterToggleWithBrandID() async {
        let brand = makeBrand(id: 1, name: "포토이즘")
        let events = LockIsolated<[MapAnalyticsEvent]>([])
        let store = makeStore(events: events)

        await store.send(.selectFilterOption(brand)) {
            $0.filteredBrands = [brand]
        }
        await store.send(.selectFilterOption(brand)) {
            $0.filteredBrands = []
        }
        await store.finish()

        #expect(events.value == [
            .mapBrandFilterToggle(action: .select, selectedCount: 1, brandName: "포토이즘", brandID: 1),
            .mapBrandFilterToggle(action: .deselect, selectedCount: 0, brandName: "포토이즘", brandID: 1)
        ])
    }

    @Test("이 지역 탭에서 즐겨찾기 탭으로 바꾸면 그때 가진 즐겨찾기 수로 즐겨찾기 탭 진입을 남기고, 이미 고른 즐겨찾기 탭을 다시 눌러도 더 남기지 않는다")
    func selectTab_fromNearbyToFavorite_logsFavoriteBoothViewOnce() async {
        var state = PhotoBoothListFeature.State()
        state.favoriteBoothCount = 3
        let events = LockIsolated<[MapAnalyticsEvent]>([])
        let store = makeStore(initialState: state, events: events)

        await store.send(.selectTab(.favorite)) {
            $0.selectedTab = .favorite
        }
        await store.send(.selectTab(.favorite))
        await store.send(.selectTab(.nearby)) {
            $0.selectedTab = .nearby
        }
        await store.finish()

        #expect(events.value == [.favoriteBoothView(favoriteBoothCount: 3)])
    }

    @Test("고른 브랜드가 없으면 브랜드 칩에 `브랜드`를 적는다")
    func searchResultBrandFilterChipTitle_withoutSelection_showsDefaultTitle() {
        let state = makeSearchResultState()

        #expect(state.searchResultBrandFilterChipTitle == "브랜드")
    }

    @Test("브랜드를 하나만 고르면 브랜드 칩에 그 브랜드 이름을 적는다")
    func searchResultBrandFilterChipTitle_withSingleSelection_showsBrandName() {
        let state = makeSearchResultState(selecting: [searchResultBrands[1]])

        #expect(state.searchResultBrandFilterChipTitle == "인생네컷")
    }

    @Test("브랜드를 여럿 고르면 필터 시트 차례의 첫 브랜드 이름과 나머지 개수를 함께 적는다")
    func searchResultBrandFilterChipTitle_withMultipleSelection_showsFirstBrandNameAndRemainingCount() {
        let state = makeSearchResultState(selecting: [searchResultBrands[2], searchResultBrands[1]])

        #expect(state.searchResultBrandFilterChipTitle == "인생네컷 외 1개")
    }

    @Test("브랜드 칩에서 강조하는 이름은 칩 문구 맨 앞의 첫 브랜드뿐이고, 고른 브랜드가 없으면 강조하지 않는다")
    func searchResultBrandFilterChipBrandName_isFirstSelectedBrandOnly() {
        #expect(makeSearchResultState().searchResultBrandFilterChipBrandName == nil)

        let state = makeSearchResultState(selecting: [searchResultBrands[2], searchResultBrands[1]])
        #expect(state.searchResultBrandFilterChipBrandName == "인생네컷")
        #expect(state.searchResultBrandFilterChipTitle.hasPrefix("인생네컷"))
    }
}


// MARK: - Helpers

private extension PhotoBoothListFeatureTests {
    /// 보낸 분석 이벤트는 `events`에 차례로 모읍니다.
    func makeStore(
        initialState: PhotoBoothListFeature.State = .init(),
        events: LockIsolated<[MapAnalyticsEvent]> = .init([])
    ) -> TestStoreOf<PhotoBoothListFeature> {
        TestStore(initialState: initialState) {
            PhotoBoothListFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { event in
                guard let event = event as? MapAnalyticsEvent else { return }
                events.withValue { $0.append(event) }
            }
        }
    }

    func makeBrand(id: Int, name: String) -> PhotoBoothBrand {
        PhotoBoothBrand(id: id, name: name, englishName: name, imageURL: nil)
    }

    /// 브랜드 필터 시트에 놓이는 차례 그대로의 검색 결과 브랜드입니다.
    var searchResultBrands: [PhotoBoothBrand] {
        [
            makeBrand(id: 1, name: "포토이즘"),
            makeBrand(id: 2, name: "인생네컷"),
            makeBrand(id: 3, name: "하루필름")
        ]
    }

    func makeSearchResultState(selecting selectedBrands: Set<PhotoBoothBrand> = []) -> PhotoBoothListFeature.State {
        var state = PhotoBoothListFeature.State()
        state.brands = IdentifiedArray(uniqueElements: searchResultBrands)
        state.isSearchResultPresented = true
        state.searchResultBrandFilters = searchResultBrands.map { PhotoBoothSearchBrandFilter(brand: $0, count: 1) }
        state.filteredBrands = selectedBrands
        return state
    }
}
