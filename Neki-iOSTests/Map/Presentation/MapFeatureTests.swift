//
//  MapFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 9/29/26.
//

import ComposableArchitecture
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct MapFeatureTests {
    @Test("지역·역 검색 결과로 바꾸면 기존 탭과 필터를 섞지 않도록 처음 값으로 되돌린다")
    func didSelectSearchResult_resetsTabAndFilters() {
        let store = makeStore()

        store.send(.photoBoothSearchAction(.delegate(.didSelectSearchResult(candidate: regionCandidate, result: regionResult))))

        #expect(store.photoBoothListState.selectedTab == .nearby)
        #expect(store.photoBoothListState.filteredBrands.isEmpty)
        #expect(store.isFavoriteMarkerFilterEnabled == false)
    }

    @Test("검색 결과에서 고른 필터가 있어도 검색을 끝내면 시트 높이와 탭·필터를 지도 탭 첫 진입 값으로 되돌린다")
    func didTapClearSearchButton_afterSearchResult_resetsToInitialValues() {
        let store = makeStore()
        store.send(.photoBoothSearchAction(.delegate(.didSelectSearchResult(candidate: regionCandidate, result: regionResult))))
        store.send(.photoBoothListAction(.selectFilterOption(life4cut)))
        store.send(.didTapFavoriteMarkerFilterButton)

        store.send(.didTapClearSearchButton)

        #expect(store.detent == MapFeature.SheetStage.first.detent)
        #expect(store.photoBoothListState.isSearchResultPresented == false)
        #expect(store.photoBoothListState.selectedTab == .nearby)
        #expect(store.photoBoothListState.filteredBrands.isEmpty)
        #expect(store.isFavoriteMarkerFilterEnabled == false)
    }

    @Test("부스를 직접 고른 검색은 탭과 필터를 그대로 두고, 검색을 끝내면 지도 탭 첫 진입 값으로 되돌린다")
    func didTapClearSearchButton_afterPhotoBoothCandidate_resetsToInitialValues() {
        let store = makeStore()
        let photoBoothResult = PhotoBoothSearchResult(photoBooths: [searchedPhotoBooth], brandFilters: [])
        store.send(.photoBoothSearchAction(.delegate(.didSelectSearchResult(candidate: .photoBooth(searchedPhotoBooth), result: photoBoothResult))))
        #expect(store.photoBoothListState.selectedTab == .favorite)
        #expect(store.photoBoothListState.filteredBrands == [photoism])
        #expect(store.isFavoriteMarkerFilterEnabled)

        store.send(.didTapClearSearchButton)

        #expect(store.detent == MapFeature.SheetStage.first.detent)
        #expect(store.photoBoothListState.selectedTab == .nearby)
        #expect(store.photoBoothListState.filteredBrands.isEmpty)
        #expect(store.isFavoriteMarkerFilterEnabled == false)
    }
}


// MARK: - Helpers

private extension MapFeatureTests {
    /// 저장한 포토부스 탭에서 포토이즘만 고르고 즐겨찾기 마커 필터를 켜 둔 지도 스토어입니다.
    ///
    /// `MapFeature.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    /// 리듀서가 곧바로 바꾸는 상태만 확인하므로 이펙트가 뒤이어 보내는 액션은 기다리지 않습니다.
    func makeStore() -> StoreOf<MapFeature> {
        var state = MapFeature.State()
        state.photoBoothListState.selectedTab = .favorite
        state.photoBoothListState.filteredBrands = [photoism]
        state.isFavoriteMarkerFilterEnabled = true

        return Store(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { _ in }
        }
    }

    var photoism: PhotoBoothBrand {
        PhotoBoothBrand(id: 1, name: "포토이즘", englishName: "PHOTOISM", imageURL: nil)
    }

    var life4cut: PhotoBoothBrand {
        PhotoBoothBrand(id: 2, name: "인생네컷", englishName: "LIFE4CUT", imageURL: nil)
    }

    var searchedPhotoBooth: PhotoBooth {
        PhotoBooth(
            id: 1,
            brand: life4cut,
            name: "강남1호점",
            coordinate: .init(latitude: 37.5021077, longitude: 127.0271830),
            address: "서울 강남구 강남대로102길 16"
        )
    }

    var regionCandidate: PhotoBoothSearchCandidate {
        .region(.init(code: "1168000000", name: "강남구", fullName: "서울특별시 강남구"))
    }

    var regionResult: PhotoBoothSearchResult {
        PhotoBoothSearchResult(
            photoBooths: [searchedPhotoBooth],
            brandFilters: [PhotoBoothSearchBrandFilter(brand: life4cut, count: 1)]
        )
    }
}
