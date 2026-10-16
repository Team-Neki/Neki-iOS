//
//  MapFeatureTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 9/29/26.
//

import ComposableArchitecture
import CoreLocation
import Foundation
import Testing
@testable import Neki_iOS

@MainActor
struct MapFeatureTests {
    @Test("지역·역 검색 결과로 바꾸면 기존 탭과 필터를 섞지 않도록 처음 값으로 되돌린다")
    func didSelectSearchResult_resetsTabAndFilters() {
        let store = makeStore()

        selectSearchResult(regionCandidate, result: regionResult, in: store)

        #expect(store.photoBoothListState.selectedTab == .nearby)
        #expect(store.photoBoothListState.filteredBrands.isEmpty)
        #expect(store.isFavoriteMarkerFilterEnabled == false)
    }

    @Test("검색 결과에서 고른 필터가 있어도 검색을 끝내면 시트 높이와 탭·필터를 지도 탭 첫 진입 값으로 되돌린다")
    func didTapClearSearchButton_afterSearchResult_resetsToInitialValues() {
        let store = makeStore()
        selectSearchResult(regionCandidate, result: regionResult, in: store)
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
        selectSearchResult(photoBoothCandidate, result: photoBoothResult, in: store)
        #expect(store.photoBoothListState.selectedTab == .favorite)
        #expect(store.photoBoothListState.filteredBrands == [photoism])
        #expect(store.isFavoriteMarkerFilterEnabled)

        store.send(.didTapClearSearchButton)

        #expect(store.detent == MapFeature.SheetStage.first.detent)
        #expect(store.photoBoothListState.selectedTab == .nearby)
        #expect(store.photoBoothListState.filteredBrands.isEmpty)
        #expect(store.isFavoriteMarkerFilterEnabled == false)
    }

    @Test("부스 후보를 고르면 조회한 그 지점을 선택하고 결과 시트는 띄우지 않는다")
    func didSelectSearchResult_withSinglePhotoBooth_selectsPhotoBooth() {
        let store = makeStore()

        selectSearchResult(photoBoothCandidate, result: photoBoothResult, in: store)

        #expect(store.selectedBooth == searchedPhotoBooth)
        #expect(store.photoBoothListState.isSearchResultPresented == false)
    }

    @Test(
        "부스 후보의 조회 결과가 없거나 한 지점으로 좁혀지지 않으면 지역·역처럼 결과 시트로 보여 준다",
        arguments: [0, 2]
    )
    func didSelectSearchResult_withoutSinglePhotoBooth_presentsSearchResult(photoBoothCount: Int) {
        let store = makeStore()
        // 지도에서 숨긴 지점이면 0건이, 같은 이름의 지점이 있으면 여러 건이 올 수 있습니다.
        let photoBooths = (0..<photoBoothCount).map { makePhotoBooth(id: String($0 + 1)) }

        selectSearchResult(
            photoBoothCandidate,
            result: PhotoBoothSearchResult(photoBooths: photoBooths, brandFilters: []),
            in: store
        )

        #expect(store.selectedBooth == nil)
        #expect(store.photoBoothListState.isSearchResultPresented)
        // 0건이면 결과가 없다는 안내가 다 보이도록 결과 없음 높이로 올립니다.
        let expectedStage: MapFeature.SheetStage = photoBoothCount == .zero ? .emptySearchResult : .second
        #expect(store.detent == expectedStage.detent)
        #expect(Array(store.photoBooths) == photoBooths)
    }

    @Test("재탐색 버튼이 떠 있을 때 부스든 지역이든 검색 결과를 고르면 버튼을 내린다", arguments: [true, false])
    func didSelectSearchResult_hidesExploreHereButton(selectsPhotoBooth: Bool) {
        let store = makeStore()
        store.send(.cameraMotionStarted)
        #expect(store.isExploreHereButtonVisible)

        if selectsPhotoBooth {
            selectSearchResult(photoBoothCandidate, result: photoBoothResult, in: store)
        } else {
            selectSearchResult(regionCandidate, result: regionResult, in: store)
        }

        #expect(store.isExploreHereButtonVisible == false)
    }

    @Test("검색 결과를 보는 동안에는 카메라가 움직여도 재탐색 버튼을 띄우지 않고, 검색을 끝내면 다시 띄운다")
    func cameraMotionStarted_showsExploreHereButtonOnlyWithoutSearchResult() {
        let store = makeStore()
        selectSearchResult(regionCandidate, result: regionResult, in: store)

        store.send(.cameraMotionStarted)
        #expect(store.isExploreHereButtonVisible == false)

        store.send(.didTapClearSearchButton)
        store.send(.cameraMotionStarted)
        #expect(store.isExploreHereButtonVisible)
    }

    @Test("부스 하나를 바로 고른 검색에서 상세를 닫으면 검색을 끝내지 않고 그 검색어로 검색 화면을 다시 연다")
    func didTapCloseDetail_afterSinglePhotoBoothSearch_presentsSearch() {
        let store = makeStore()
        selectSearchResult(photoBoothCandidate, result: photoBoothResult, in: store)

        store.send(.didTapCloseDetail)

        #expect(store.isSearchPresented)
        #expect(store.selectedBooth == nil)
        #expect(store.photoBoothSearchState.searchText == "강남")
        #expect(store.photoBoothSearchState.query?.rawValue == "강남")
        #expect(store.appliedSearchQuery?.rawValue == "강남")
    }

    @Test("상세를 닫고 돌아온 검색 화면에서 후보를 고르지 않고 나가면 검색을 끝내고 지도 탭 첫 진입 값으로 되돌린다")
    func dismissSearch_afterClosingSinglePhotoBoothDetail_endsSearch() {
        let store = makeStore()
        selectSearchResult(photoBoothCandidate, result: photoBoothResult, in: store)
        store.send(.didTapCloseDetail)

        store.send(.photoBoothSearchAction(.dismissSearch))

        #expect(store.isSearchPresented == false)
        #expect(store.appliedSearchQuery == nil)
        #expect(store.detent == MapFeature.SheetStage.first.detent)
        #expect(store.photoBoothListState.selectedTab == .nearby)
        #expect(store.photoBoothListState.filteredBrands.isEmpty)
        #expect(store.isFavoriteMarkerFilterEnabled == false)
    }

    @Test("부스 상세를 띄운 채 검색어를 눌러 검색 화면에 들어갔다가 나오면 부스 상세로 돌아온다")
    func dismissSearch_afterTappingSearchFieldOnPhotoBoothDetail_keepsDetail() {
        let store = makeStore()
        selectSearchResult(photoBoothCandidate, result: photoBoothResult, in: store)
        store.send(.didTapSearchField)

        store.send(.photoBoothSearchAction(.dismissSearch))

        #expect(store.selectedBooth == searchedPhotoBooth)
        #expect(store.appliedSearchQuery?.rawValue == "강남")
    }

    @Test(
        "지역이나 여러 지점으로 나온 부스처럼 결과 시트로 보여 준 검색은 상세를 닫으면 결과 시트로 돌아간다",
        arguments: [false, true]
    )
    func didTapCloseDetail_afterSearchResultSheet_returnsToSearchResult(isPhotoBoothCandidate: Bool) {
        let store = makeStore()
        selectSearchResultSheet(in: store, isPhotoBoothCandidate: isPhotoBoothCandidate)
        store.send(.didTapBooth(searchedPhotoBooth))

        store.send(.didTapCloseDetail)

        #expect(store.isSearchPresented == false)
        #expect(store.detent == MapFeature.SheetStage.second.detent)
        #expect(store.photoBoothListState.isSearchResultPresented)
    }

    @Test(
        "결과 시트를 보다가 검색어를 눌러 검색 화면에 들어갔다가 나오면 검색을 끝내지 않는다",
        arguments: [false, true]
    )
    func dismissSearch_afterTappingSearchFieldOnSearchResult_keepsSearch(isPhotoBoothCandidate: Bool) {
        let store = makeStore()
        selectSearchResultSheet(in: store, isPhotoBoothCandidate: isPhotoBoothCandidate)
        store.send(.didTapSearchField)

        store.send(.photoBoothSearchAction(.dismissSearch))

        #expect(store.appliedSearchQuery?.rawValue == "강남")
        #expect(store.photoBoothListState.isSearchResultPresented)
    }

    @Test("부스 하나를 바로 고른 뒤 지역으로 다시 검색하면 상세를 닫을 때 결과 시트로 돌아간다")
    func didTapCloseDetail_afterResearchingRegionFromSinglePhotoBooth_returnsToSearchResult() {
        let store = makeStore()
        selectSearchResult(photoBoothCandidate, result: photoBoothResult, in: store)
        store.send(.didTapSearchField)
        selectSearchResult(regionCandidate, result: regionResult, in: store)
        store.send(.didTapBooth(searchedPhotoBooth))

        store.send(.didTapCloseDetail)

        #expect(store.isSearchPresented == false)
        #expect(store.detent == MapFeature.SheetStage.second.detent)
    }

    @Test("부스 하나를 바로 고른 검색이라도 열린 상세가 없으면 빈 지도를 눌러도 검색 화면을 열지 않는다")
    func didTapCloseDetail_withoutDetailAfterSinglePhotoBoothSearch_keepsMap() {
        let store = makeStore()
        selectSearchResult(photoBoothCandidate, result: photoBoothResult, in: store)
        // 검색 화면을 거치지 않고 상세만 닫힌 상태를 만듭니다.
        store.send(.didTapGoBackToMapButton)

        store.send(.didTapCloseDetail)

        #expect(store.isSearchPresented == false)
    }

    @Test(
        "검색 결과를 보는 중에 현위치 버튼을 누르면 검색과 시트 높이를 그대로 두고, 위치를 따라가도 검색을 유지한다",
        arguments: [false, true]
    )
    func didTapCurrentLocationButton_whileSearching_keepsSearch(isPhotoBoothCandidate: Bool) {
        let store = makeStore()
        store.send(.updateLocationAuthorization(.authorizedWhenInUse))
        selectSearchResultSheet(in: store, isPhotoBoothCandidate: isPhotoBoothCandidate)

        store.send(.didTapCurrentLocationButton)
        store.send(.updateUserLocation(.success(userLocation)))

        #expect(store.appliedSearchQuery?.rawValue == "강남")
        #expect(store.photoBoothListState.isSearchResultPresented)
        #expect(store.detent == MapFeature.SheetStage.second.detent)
        #expect(store.isUserTrackingMode)
        #expect(store.cameraMoveRequest.coordinate == userCoordinate)
    }

    @Test("검색 중이 아니면 현위치 버튼을 누를 때 시트를 처음 높이로 내린다")
    func didTapCurrentLocationButton_withoutSearch_resetsSheet() {
        let store = makeStore()
        store.send(.updateLocationAuthorization(.authorizedWhenInUse))
        store.send(.binding(.set(\.detent, MapFeature.SheetStage.second.detent)))

        store.send(.didTapCurrentLocationButton)

        #expect(store.detent == MapFeature.SheetStage.first.detent)
        #expect(store.isUserTrackingMode)
    }

    @Test("위치 권한을 받으면 검색 중이 아닐 때 상세를 닫고 시트를 처음 높이로 내린 뒤 현위치를 따라간다")
    func updateLocationAuthorization_withoutSearch_returnsToMapModeAndFollowsUserLocation() {
        let store = makeStore()
        store.send(.didTapBooth(searchedPhotoBooth))
        store.send(.updateUserLocation(.success(userLocation)))

        store.send(.updateLocationAuthorization(.authorizedWhenInUse))

        #expect(store.selectedBooth == nil)
        #expect(store.detent == MapFeature.SheetStage.first.detent)
        #expect(store.isUserTrackingMode)
        #expect(store.cameraMoveRequest.coordinate == userCoordinate)
    }

    @Test("검색 결과를 보는 중에 위치 권한을 받으면 검색과 시트 높이를 그대로 두고 현위치를 따라간다")
    func updateLocationAuthorization_whileSearching_keepsSearchAndFollowsUserLocation() {
        let store = makeStore()
        store.send(.updateUserLocation(.success(userLocation)))
        selectSearchResultSheet(in: store, isPhotoBoothCandidate: false)

        store.send(.updateLocationAuthorization(.authorizedWhenInUse))

        #expect(store.appliedSearchQuery?.rawValue == "강남")
        #expect(store.photoBoothListState.isSearchResultPresented)
        #expect(store.detent == MapFeature.SheetStage.second.detent)
        #expect(store.isUserTrackingMode)
        #expect(store.cameraMoveRequest.coordinate == userCoordinate)
    }

    @Test(
        "검색 결과를 보다가 다른 탭에서 돌아오면 검색을 끝내고 상세·시트 높이와 탭·필터를 지도 탭 첫 진입 값으로 되돌린다",
        arguments: [false, true]
    )
    func didEnterTab_whileSearching_endsSearchAndResetsToInitialValues(isSinglePhotoBoothSearch: Bool) {
        let store = makeStore()
        if isSinglePhotoBoothSearch {
            // 부스를 바로 고른 검색은 탭과 필터를 그대로 두므로, 저장한 포토부스 탭·포토이즘 필터·하트가 켜진 채로 남습니다.
            selectSearchResult(photoBoothCandidate, result: photoBoothResult, in: store)
        } else {
            selectSearchResultSheet(in: store, isPhotoBoothCandidate: false)
            store.send(.photoBoothListAction(.selectFilterOption(life4cut)))
            store.send(.didTapFavoriteMarkerFilterButton)
        }

        store.send(.didEnterTab)

        #expect(store.appliedSearchQuery == nil)
        #expect(store.isSinglePhotoBoothSearchApplied == false)
        #expect(store.selectedBooth == nil)
        #expect(store.detent == MapFeature.SheetStage.first.detent)
        #expect(store.photoBoothListState.isSearchResultPresented == false)
        #expect(store.photoBoothListState.selectedTab == .nearby)
        #expect(store.photoBoothListState.filteredBrands.isEmpty)
        #expect(store.isFavoriteMarkerFilterEnabled == false)
    }

    @Test("검색 중이 아니면 다른 탭에서 돌아올 때 탭·필터·하트는 그대로 두고, 위치 권한이 있으면 상세를 닫고 시트를 처음 높이로 내린다")
    func didEnterTab_withoutSearch_keepsTabAndFilters() {
        let store = makeStore()
        store.send(.updateLocationAuthorization(.authorizedWhenInUse))
        store.send(.didTapBooth(searchedPhotoBooth))

        store.send(.didEnterTab)

        #expect(store.selectedBooth == nil)
        #expect(store.detent == MapFeature.SheetStage.first.detent)
        #expect(store.photoBoothListState.selectedTab == .favorite)
        #expect(store.photoBoothListState.filteredBrands == [photoism])
        #expect(store.isFavoriteMarkerFilterEnabled)
    }

    @Test("위치 권한이 없으면 검색 중이 아닐 때 다른 탭에서 돌아와도 상세와 시트 높이를 그대로 둔다")
    func didEnterTab_withoutLocationAuthorization_keepsDetail() {
        let store = makeStore()
        store.send(.updateLocationAuthorization(.denied))
        store.send(.didTapBooth(searchedPhotoBooth))

        store.send(.didEnterTab)

        #expect(store.selectedBooth == searchedPhotoBooth)
        #expect(store.detent == MapFeature.SheetStage.photoBoothSelected.detent)
    }

    @Test("검색 화면을 띄운 채로 탭이 바뀌었다가 돌아오면 검색 화면을 닫고 검색어를 비운다")
    func didEnterTab_whileSearchPresented_dismissesSearch() {
        let store = makeStore()
        store.send(.didTapSearchField)
        store.send(.photoBoothSearchAction(.binding(.set(\.searchText, "홍대"))))

        store.send(.didEnterTab)

        #expect(store.isSearchPresented == false)
        #expect(store.photoBoothSearchState.searchText.isEmpty)
        #expect(store.photoBoothSearchState.mode == .inactive)
    }

    @Test("지역·역 검색 결과가 0곳이면 결과 없음 높이로 올리고, 그 동안에는 두 번째 높이 대신 결과 없음 높이로 끌어 맞춘다")
    func emptySearchResult_usesEmptySearchResultHeight() {
        let store = makeStore()
        #expect(store.sheetDetents == MapFeature.SheetStage.detents(isSearchResultMessagePresented: false))

        selectSearchResult(regionCandidate, result: PhotoBoothSearchResult(photoBooths: [], brandFilters: []), in: store)

        #expect(store.detent == MapFeature.SheetStage.emptySearchResult.detent)
        #expect(store.sheetDetents.contains(MapFeature.SheetStage.emptySearchResult.detent))
        #expect(store.sheetDetents.contains(MapFeature.SheetStage.second.detent) == false)

        // 빈 지도를 눌러도 결과 없음 높이를 그대로 둡니다.
        store.send(.didTapCloseDetail)
        #expect(store.detent == MapFeature.SheetStage.emptySearchResult.detent)

        store.send(.didTapClearSearchButton)
        #expect(store.sheetDetents == MapFeature.SheetStage.detents(isSearchResultMessagePresented: false))
    }

    @Test("검색 결과가 있으면 지금처럼 두 번째 높이로 보여 주고 끌어 맞추는 높이도 바꾸지 않는다")
    func searchResult_withPhotoBooths_keepsSecondHeight() {
        let store = makeStore()

        selectSearchResult(regionCandidate, result: regionResult, in: store)

        #expect(store.detent == MapFeature.SheetStage.second.detent)
        #expect(store.sheetDetents == MapFeature.SheetStage.detents(isSearchResultMessagePresented: false))
    }

    @Test(
        "검색 결과가 오면 목록 계산을 기다리지 않고 결과 목록을 바로 채워, 결과가 있는데 0곳으로 보이는 순간이 없다",
        arguments: [false, true]
    )
    func searchResultResponse_fillsVisibleBoothsImmediately(isPhotoBoothCandidate: Bool) {
        let store = makeStore()

        selectSearchResultSheet(in: store, isPhotoBoothCandidate: isPhotoBoothCandidate)

        // 응답을 반영한 직후라 목록 계산 이펙트는 아직 끝나지 않았습니다.
        let result = isPhotoBoothCandidate ? multiplePhotoBoothResult : regionResult
        #expect(Array(store.photoBoothListState.visibleBooths) == result.photoBooths)
        #expect(store.isSearchResultMessagePresented == false)
    }

    @Test("같은 부스를 다시 골라도 새 이동 요청을 만들어, 지도를 옮긴 뒤에도 그 부스로 다시 옮긴다")
    func selectingSamePhotoBoothAgain_issuesNewMoveRequest() {
        let store = makeStore()
        store.send(.didTapBooth(searchedPhotoBooth))
        let firstGeneration = store.cameraMoveRequest.generation

        store.send(.didTapBoothCard)

        #expect(store.cameraMoveRequest.generation == firstGeneration + 1)
        #expect(store.cameraMoveRequest.coordinate == searchedPhotoBooth.coordinate)
    }

    @Test("카메라가 멈춘 위치는 이동 요청에 되돌려 쓰지 않는다")
    func cameraStopped_keepsMoveRequest() {
        let store = makeStore()
        store.send(.didTapBooth(searchedPhotoBooth))
        let request = store.cameraMoveRequest
        let stoppedBounds = GeographicBoundingBox(minLatitude: 37.49, minLongitude: 127.02, maxLatitude: 37.50, maxLongitude: 127.03)

        store.send(.mapLoaded(stoppedBounds))
        store.send(.cameraMotionEnded(stoppedBounds))

        #expect(store.cameraMoveRequest == request)
        #expect(store.currentBounds == stoppedBounds)
    }

    @Test("지점 이동과 영역 맞춤 요청은 나중에 들어온 것만 남긴다")
    func moveAndFitRequests_keepOnlyLatest() {
        let store = makeStore()
        store.send(.didTapBooth(searchedPhotoBooth))
        selectSearchResult(regionCandidate, result: regionResult, in: store)
        #expect(store.cameraMoveRequest.coordinate == nil)
        #expect(store.cameraFitRequest.bounds != nil)

        store.send(.didTapBooth(searchedPhotoBooth))
        #expect(store.cameraMoveRequest.coordinate == searchedPhotoBooth.coordinate)
        #expect(store.cameraFitRequest.bounds == nil)
    }

    @Test("지역·역 후보를 고르면 검색 화면을 바로 닫고, 결과가 오기 전까지 결과 시트 높이에서 로딩을 띄운다")
    func didSelectCandidate_withRegion_dismissesSearchAndShowsLoading() {
        let store = makeStore()
        store.send(.didTapSearchField)

        selectCandidate(regionCandidate, in: store)

        #expect(store.isSearchPresented == false)
        #expect(store.appliedSearchQuery == searchQuery)
        #expect(store.detent == MapFeature.SheetStage.second.detent)
        #expect(store.photoBoothListState.isSearchResultPresented)
        #expect(store.photoBoothListState.searchResultPhase == .loading)
        // 지역·역 검색 결과에는 기존 탭과 필터를 섞지 않습니다.
        #expect(store.photoBoothListState.selectedTab == .nearby)
        #expect(store.photoBoothListState.filteredBrands.isEmpty)
    }

    @Test("포토부스 후보를 고르면 열려 있던 상세를 닫고, 결과가 오기 전까지 시트를 가장 낮은 높이에 두고 로딩을 띄운다")
    func didSelectCandidate_withPhotoBooth_showsLoadingAtLowestSheet() {
        let store = makeStore()
        store.send(.didTapBooth(searchedPhotoBooth))

        selectCandidate(photoBoothCandidate, in: store)

        #expect(store.selectedBooth == nil)
        #expect(store.detent == MapFeature.SheetStage.first.detent)
        #expect(store.photoBoothListState.isSearchResultPresented)
        #expect(store.photoBoothListState.searchResultPhase == .loading)
        // 부스를 바로 고른 검색은 지도에 한 지점만 찍으므로 탭과 필터를 그대로 둡니다.
        #expect(store.photoBoothListState.selectedTab == .favorite)
        #expect(store.photoBoothListState.filteredBrands == [photoism])
    }

    @Test("후보를 고르면 결과로 바뀔 기존 마커를 비우고, 진행 중이던 영역 조회가 늦게 보낸 부스는 반영하지 않는다")
    func didSelectCandidate_clearsMarkersAndIgnoresLateAreaFetch() {
        let store = makeStore()
        store.send(.fetchPhotoBooths(bounds: gangnamBounds))
        let areaFetchGeneration = store.photoBoothFetchContext.generation
        store.send(.photoBoothChunkLoaded([makePhotoBooth(id: "9")], generation: areaFetchGeneration))
        #expect(store.photoBooths.isEmpty == false)

        selectCandidate(regionCandidate, in: store)

        #expect(store.photoBooths.isEmpty)
        store.send(.photoBoothChunkLoaded([makePhotoBooth(id: "10")], generation: areaFetchGeneration))
        #expect(store.photoBooths.isEmpty)
    }

    @Test("후보를 고르면 지도가 부스 목록과 필터를 함께 조회하고, 검색 화면이 넘긴 기준 좌표로 조회한다")
    func didSelectCandidate_fetchesPhotoBoothsAndBrandFilters() async {
        let photoBoothRequests = LockIsolated<[PhotoBoothSearchCandidate]>([])
        let origins = LockIsolated<[GeographicCoordinate?]>([])
        let filterRequests = LockIsolated<[PhotoBoothSearchCandidate]>([])
        let result = regionResult
        let store = makeStore {
            $0.photoBoothClient.fetchSearchPhotoBooths = { candidate, origin in
                photoBoothRequests.withValue { $0.append(candidate) }
                origins.withValue { $0.append(origin) }
                return result.photoBooths
            }
            $0.photoBoothClient.fetchSearchBrandFilters = { candidate in
                filterRequests.withValue { $0.append(candidate) }
                return result.brandFilters
            }
        }

        await selectCandidate(regionCandidate, distanceOrigin: userCoordinate, isDistanceVisible: true, in: store).finish()

        // 요청 body가 같아 고른 후보 그대로 필터도 함께 조회합니다.
        #expect(photoBoothRequests.value == [regionCandidate])
        #expect(filterRequests.value == [regionCandidate])
        // 후보 목록과 결과 목록의 거리가 어긋나지 않도록 검색 화면이 고정한 기준 좌표로 조회합니다.
        #expect(origins.value == [userCoordinate])
        #expect(store.photoBoothListState.searchResultPhase == .loaded)
        #expect(Array(store.photoBooths) == result.photoBooths)
        #expect(store.photoBoothListState.searchResultBrandFilters == result.brandFilters)
    }

    @Test("결과를 조회하는 중에 다른 후보를 고르면 앞서 고른 후보의 응답은 버리고 나중에 고른 후보의 결과만 반영한다")
    func searchResultResponse_fromPreviousCandidate_isIgnored() {
        let store = makeStore()
        selectCandidate(regionCandidate, in: store)
        let previousGeneration = store.searchResultFetchGeneration
        selectCandidate(photoBoothCandidate, in: store)

        store.send(.searchResultResponse(.success(regionResult), candidate: regionCandidate, generation: previousGeneration))
        #expect(store.photoBoothListState.searchResultPhase == .loading)
        #expect(store.photoBooths.isEmpty)

        store.send(.searchResultResponse(
            .success(photoBoothResult),
            candidate: photoBoothCandidate,
            generation: store.searchResultFetchGeneration
        ))
        #expect(store.selectedBooth == searchedPhotoBooth)
        #expect(store.isSinglePhotoBoothSearchApplied)
    }

    @Test(
        "조회가 실패하면 검색어를 남긴 채 시트에 실패를 띄우고, 부스 후보든 지역 후보든 결과 없음과 같은 높이로 올린다",
        arguments: [false, true]
    )
    func searchResultResponse_withFailure_showsFailureInSheet(isPhotoBoothCandidate: Bool) {
        let store = makeStore()
        let candidate = isPhotoBoothCandidate ? photoBoothCandidate : regionCandidate
        selectCandidate(candidate, in: store)

        store.send(.searchResultResponse(.failure(.network), candidate: candidate, generation: store.searchResultFetchGeneration))

        #expect(store.photoBoothListState.isSearchResultPresented)
        #expect(store.photoBoothListState.searchResultPhase == .failure(.network))
        #expect(store.detent == MapFeature.SheetStage.emptySearchResult.detent)
        // 실패 문구를 보여 주는 동안에는 두 번째 높이 대신 결과 없음 높이로 끌어 맞춥니다.
        #expect(store.sheetDetents == MapFeature.SheetStage.detents(isSearchResultMessagePresented: true))
        // 상단 검색 필드를 누르면 이 검색어로 검색 화면에 돌아가 다시 고를 수 있습니다.
        #expect(store.appliedSearchQuery == searchQuery)
    }

    @Test("로딩 중에 지도에서 연 부스 상세는 조회가 실패해도 그대로 두고, 상세를 닫으면 결과 없음 높이로 실패를 보여 준다")
    func searchResultResponse_withFailure_whileDetailIsOpen_keepsDetail() {
        let store = makeStore()
        selectCandidate(regionCandidate, in: store)
        // 검색 중에도 화면 안의 즐겨찾기 마커는 지도에 남아 있어 눌러 상세를 열 수 있습니다.
        store.send(.didTapBooth(searchedPhotoBooth))

        store.send(.searchResultResponse(
            .failure(.network),
            candidate: regionCandidate,
            generation: store.searchResultFetchGeneration
        ))

        #expect(store.selectedBooth == searchedPhotoBooth)
        #expect(store.detent == MapFeature.SheetStage.photoBoothSelected.detent)

        store.send(.didTapCloseDetail)
        #expect(store.selectedBooth == nil)
        #expect(store.detent == MapFeature.SheetStage.emptySearchResult.detent)
    }

    @Test("검색 결과를 보는 동안에는 즐겨찾기 마커 필터 버튼을 숨기고, 검색을 끝내면 다시 보여 준다", arguments: [false, true])
    func isFavoriteMarkerFilterButtonVisible_isFalseWhileSearchIsApplied(isPhotoBoothCandidate: Bool) {
        let store = makeStore()
        #expect(store.isFavoriteMarkerFilterButtonVisible)

        // 결과를 기다리는 동안에도 검색 결과를 보는 중이라 숨깁니다.
        selectCandidate(isPhotoBoothCandidate ? photoBoothCandidate : regionCandidate, in: store)
        #expect(store.isFavoriteMarkerFilterButtonVisible == false)

        store.send(.didTapClearSearchButton)
        #expect(store.isFavoriteMarkerFilterButtonVisible)
    }

    @Test(
        "위치를 모른 채 고른 후보의 결과는 결과 목록과 부스 상세에 거리를 표기하지 않고, 검색을 끝내면 부스 상세에 다시 표기한다",
        arguments: [false, true], [false, true]
    )
    func searchResultDistance_followsDistanceVisibilityOfSearch(isPhotoBoothCandidate: Bool, isDistanceVisible: Bool) {
        let store = makeStore()
        let candidate = isPhotoBoothCandidate ? photoBoothCandidate : regionCandidate
        let result = isPhotoBoothCandidate ? photoBoothResult : regionResult
        selectCandidate(candidate, isDistanceVisible: isDistanceVisible, in: store)
        store.send(.searchResultResponse(.success(result), candidate: candidate, generation: store.searchResultFetchGeneration))
        // 부스를 바로 고른 검색은 결과가 오면 상세를 띄우고, 지역 검색은 결과 목록에서 부스를 골라 상세를 엽니다.
        if isPhotoBoothCandidate == false {
            store.send(.photoBoothListAction(.didTapBooth(searchedPhotoBooth)))
        }

        #expect(store.selectedBooth == searchedPhotoBooth)
        #expect(store.photoBoothListState.isSearchResultDistanceVisible == isDistanceVisible)
        #expect(store.isSelectedBoothDistanceVisible == isDistanceVisible)

        // 검색을 끝내면 지도 영역 조회의 거리로 돌아가므로 다시 표기합니다.
        store.send(.didTapClearSearchButton)
        #expect(store.isSelectedBoothDistanceVisible)
    }

    @Test("필터 조회가 실패하면 부스 목록도 반영하지 않고 시트에 실패를 띄운다")
    func didSelectCandidate_whenBrandFilterFails_showsFailure() async {
        struct BrandFilterError: Error {}
        let photoBooths = regionResult.photoBooths
        let store = makeStore {
            $0.photoBoothClient.fetchSearchPhotoBooths = { _, _ in photoBooths }
            $0.photoBoothClient.fetchSearchBrandFilters = { _ in throw BrandFilterError() }
        }

        await selectCandidate(regionCandidate, in: store).finish()

        #expect(store.photoBoothListState.searchResultPhase == .failure(.unknown))
        #expect(store.photoBooths.isEmpty)
    }

    @Test("결과를 조회하는 중에 검색을 끝내면 늦게 온 응답을 반영하지 않는다")
    func didTapClearSearchButton_whileFetchingSearchResult_ignoresLateResponse() {
        let store = makeStore()
        selectCandidate(regionCandidate, in: store)
        let generation = store.searchResultFetchGeneration

        store.send(.didTapClearSearchButton)
        store.send(.searchResultResponse(.success(regionResult), candidate: regionCandidate, generation: generation))

        #expect(store.appliedSearchQuery == nil)
        #expect(store.photoBoothListState.isSearchResultPresented == false)
        #expect(store.photoBooths.isEmpty)
    }

    @Test("결과를 조회하는 중에 다른 탭에서 돌아오면 첫 지도 화면으로 되돌리고 늦게 온 응답을 반영하지 않는다")
    func didEnterTab_whileFetchingSearchResult_ignoresLateResponse() {
        let store = makeStore()
        selectCandidate(regionCandidate, in: store)
        let generation = store.searchResultFetchGeneration

        store.send(.didEnterTab)
        store.send(.searchResultResponse(.success(regionResult), candidate: regionCandidate, generation: generation))

        #expect(store.appliedSearchQuery == nil)
        #expect(store.photoBoothListState.isSearchResultPresented == false)
        #expect(store.photoBoothListState.searchResultPhase == .loaded)
        #expect(store.photoBooths.isEmpty)
    }

    @Test("로딩 중에 현위치 버튼으로 위치를 따라가도, 결과가 오면 추적을 끄고 결과에 맞춰 카메라를 옮긴다")
    func searchResultResponse_afterFollowingUserLocation_movesCameraToResult() {
        let store = makeStore()
        store.send(.updateLocationAuthorization(.authorizedWhenInUse))
        store.send(.updateUserLocation(.success(userLocation)))
        selectCandidate(regionCandidate, in: store)
        store.send(.didTapCurrentLocationButton)
        #expect(store.isUserTrackingMode)

        store.send(.searchResultResponse(.success(regionResult), candidate: regionCandidate, generation: store.searchResultFetchGeneration))

        #expect(store.isUserTrackingMode == false)
        #expect(store.cameraFitRequest.bounds != nil)
        #expect(store.cameraMoveRequest.coordinate == nil)
    }

    @Test("로딩 중에 검색 화면을 다시 열어도 조회를 이어 가고, 결과가 오면 검색 화면은 그대로 둔 채 지도에 반영한다")
    func searchResultResponse_whileSearchReopened_keepsSearchPresented() {
        let store = makeStore()
        selectCandidate(regionCandidate, in: store)
        store.send(.didTapSearchField)

        store.send(.searchResultResponse(.success(regionResult), candidate: regionCandidate, generation: store.searchResultFetchGeneration))

        #expect(store.isSearchPresented)
        #expect(store.photoBoothListState.searchResultPhase == .loaded)
        #expect(Array(store.photoBooths) == regionResult.photoBooths)
    }
}


// MARK: - Helpers

private extension MapFeatureTests {
    /// 저장한 포토부스 탭에서 포토이즘만 고르고 즐겨찾기 마커 필터를 켜 둔 지도 스토어입니다.
    ///
    /// `MapFeature.State`가 `Equatable`이 아니어서 `TestStore` 대신 `Store`로 액션을 보냅니다.
    /// 리듀서가 곧바로 바꾸는 상태만 확인하므로 이펙트가 뒤이어 보내는 액션은 기다리지 않습니다.
    /// 후보를 고른 뒤의 조회와 영역 조회는 응답을 붙잡아 두므로, 조회 결과는 테스트가 직접 보냅니다.
    func makeStore(
        dependencies updateDependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> StoreOf<MapFeature> {
        var state = MapFeature.State()
        state.photoBoothListState.selectedTab = .favorite
        state.photoBoothListState.filteredBrands = [photoism]
        state.isFavoriteMarkerFilterEnabled = true

        return Store(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.analyticsClient.logEvent = { _ in }
            // 검색 화면을 다시 열면 지도에 반영 중인 검색어로 후보를 다시 요청하므로 빈 페이지로 응답합니다.
            $0.photoBoothClient.searchCandidates = { _, type, _, _ in
                PhotoBoothSearchCandidatePage(type: type, candidates: [], hasNext: false)
            }
            $0.photoBoothClient.fetchSearchPhotoBooths = { _, _ in
                try await Task.sleep(for: .seconds(60))
                return []
            }
            $0.photoBoothClient.fetchSearchBrandFilters = { _ in
                try await Task.sleep(for: .seconds(60))
                return []
            }
            $0.photoBoothClient.fetchPhotoBooths = { _ in AsyncThrowingStream { _ in } }
            // 위치 권한을 받으면 위치 추적을 시작하므로 위치를 보내지 않는 스트림으로 둡니다. 위치는 테스트에서 직접 보냅니다.
            $0.mapClient.trackingLocation = { .finished }
            updateDependencies(&$0)
        }
    }

    /// 검색 화면에서 `강남`을 검색해 후보를 골랐을 때 지도로 넘어오는 검색어입니다.
    var searchQuery: PhotoBoothSearchQuery {
        PhotoBoothSearchQuery(rawValue: "강남")
    }

    /// 검색 화면에서 후보를 고릅니다. 지도는 이때부터 그 후보의 부스 목록을 조회합니다.
    ///
    /// 기준 좌표와 거리 표기 여부를 주지 않으면 위치를 모른 채 검색한 것처럼 기본 좌표로 넘기고 거리를 표기하지 않습니다.
    @discardableResult
    func selectCandidate(
        _ candidate: PhotoBoothSearchCandidate,
        distanceOrigin: GeographicCoordinate = PhotoBoothSearchFeature.Constants.defaultDistanceOrigin,
        isDistanceVisible: Bool = false,
        in store: StoreOf<MapFeature>
    ) -> StoreTask {
        store.send(.photoBoothSearchAction(.delegate(.didSelectCandidate(
            candidate: candidate,
            query: searchQuery,
            distanceOrigin: distanceOrigin,
            isDistanceVisible: isDistanceVisible
        ))))
    }

    /// 후보를 고르고, 지도가 조회한 결과가 도착한 상태로 만듭니다.
    func selectSearchResult(
        _ candidate: PhotoBoothSearchCandidate,
        result: PhotoBoothSearchResult,
        in store: StoreOf<MapFeature>
    ) {
        selectCandidate(candidate, in: store)
        store.send(.searchResultResponse(.success(result), candidate: candidate, generation: store.searchResultFetchGeneration))
    }

    var userLocation: CLLocation {
        CLLocation(latitude: 37.4979, longitude: 127.0276)
    }

    var userCoordinate: GeographicCoordinate {
        GeographicCoordinate(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
    }

    var gangnamBounds: GeographicBoundingBox {
        GeographicBoundingBox(minLatitude: 37.49, minLongitude: 127.02, maxLatitude: 37.50, maxLongitude: 127.03)
    }

    var photoism: PhotoBoothBrand {
        PhotoBoothBrand(id: 1, name: "포토이즘", englishName: "PHOTOISM", imageURL: nil)
    }

    var life4cut: PhotoBoothBrand {
        PhotoBoothBrand(id: 2, name: "인생네컷", englishName: "LIFE4CUT", imageURL: nil)
    }

    var searchedPhotoBooth: PhotoBooth {
        makePhotoBooth(id: "1")
    }

    func makePhotoBooth(id: PhotoBooth.ID) -> PhotoBooth {
        PhotoBooth(
            id: id,
            brand: life4cut,
            name: "강남\(id)호점",
            coordinate: .init(latitude: 37.5021077, longitude: 127.0271830),
            address: "서울 강남구 강남대로102길 16"
        )
    }

    var photoBoothCandidate: PhotoBoothSearchCandidate {
        PhotoBoothSearchCandidate(type: .photoBooth, keyword: "인생네컷 강남1호점", filterGroup: .init())
    }

    var photoBoothResult: PhotoBoothSearchResult {
        PhotoBoothSearchResult(photoBooths: [searchedPhotoBooth], brandFilters: [])
    }

    var regionCandidate: PhotoBoothSearchCandidate {
        PhotoBoothSearchCandidate(type: .region, keyword: "서울특별시 강남구", filterGroup: .init())
    }

    var regionResult: PhotoBoothSearchResult {
        PhotoBoothSearchResult(
            photoBooths: [searchedPhotoBooth],
            brandFilters: [PhotoBoothSearchBrandFilter(brand: life4cut, count: 1)]
        )
    }

    /// 같은 이름의 지점이 여러 곳이라 부스 후보인데도 결과 시트로 보여 주는 조회 결과입니다.
    var multiplePhotoBoothResult: PhotoBoothSearchResult {
        PhotoBoothSearchResult(photoBooths: [makePhotoBooth(id: "1"), makePhotoBooth(id: "2")], brandFilters: [])
    }

    /// 결과 시트로 보여 주는 검색 결과를 고릅니다. 지역 후보 또는 여러 지점으로 나온 부스 후보입니다.
    func selectSearchResultSheet(in store: StoreOf<MapFeature>, isPhotoBoothCandidate: Bool) {
        let candidate = isPhotoBoothCandidate ? photoBoothCandidate : regionCandidate
        let result = isPhotoBoothCandidate ? multiplePhotoBoothResult : regionResult
        selectSearchResult(candidate, result: result, in: store)
    }
}
