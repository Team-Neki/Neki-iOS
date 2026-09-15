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
}


// MARK: - Helpers

private extension PhotoBoothListFeatureTests {
    func makeStore(initialState: PhotoBoothListFeature.State = .init()) -> TestStoreOf<PhotoBoothListFeature> {
        TestStore(initialState: initialState) {
            PhotoBoothListFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { _ in }
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
