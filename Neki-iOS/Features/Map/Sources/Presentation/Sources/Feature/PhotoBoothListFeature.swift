//
//  PhotoBoothListFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/7/26.
//

import Foundation
import ComposableArchitecture

@Reducer
public struct PhotoBoothListFeature {
    public enum ListTab: CaseIterable, Identifiable {
        case nearby
        case favorite

        public var id: Self { self }

        var title: String {
            switch self {
            case .nearby: return "이 지역 포토부스"
            case .favorite: return "저장한 포토부스"
            }
        }
    }

    @ObservableState
    public struct State {
        /// 사용자가 저장한 순서의 전체 브랜드입니다. 순서 편집의 대상이기도 합니다.
        var brands: IdentifiedArrayOf<PhotoBoothBrand> = []
        /// 지역·역 검색 결과를 보고 있을 때, 그 목록에 실제로 있는 브랜드입니다.
        ///
        /// 지도 영역 조회로 돌아가면 `nil`이 되어 다시 전체 브랜드를 칩으로 노출합니다.
        var searchResultBrandFilters: [PhotoBoothSearchBrandFilter]?
        var filteredBrands: Set<PhotoBoothBrand> = []

        /// 필터 칩으로 노출할 브랜드입니다.
        ///
        /// 검색 결과를 보는 동안에는 그 범위에 없는 브랜드를 눌러 빈 화면을 보는 일이 없도록 목록을 좁힙니다.
        ///
        /// - Important: **현재 UI에는 검색 결과에 필터가 없습니다.** ``searchResultBrandFilters``가
        ///   채워지는 조건과 ``isSearchResultPresented``가 참인 조건이 같은데, 시트는 검색 결과일 때
        ///   필터 칩 영역 자체를 노출하지 않으므로 아래 좁히는 분기는 화면에 닿지 않습니다.
        ///   `PhotoBoothSearchBrandFilter.count`도 어디에도 표시되지 않습니다.
        /// - TODO: 검색 결과에서도 필터 칩을 노출할지 확정한 뒤 작업 요망.
        ///   노출한다면 `NearPhotoBoothListSheet`의 검색 결과 분기에 칩 영역을 추가하고,
        ///   노출하지 않는다면 필터 조회(`/search/filter`)와 이 상태를 함께 걷어내면 됩니다.
        var filterBrands: IdentifiedArrayOf<PhotoBoothBrand> {
            guard let searchResultBrandFilters else { return brands }
            return IdentifiedArray(uniqueElements: searchResultBrandFilters.map(\.brand))
        }
        
        /// 검색 결과를 보여 주는 중인지 여부입니다.
        ///
        /// 검색 결과는 고른 후보의 범위 전체가 이미 목록이므로 탭과 브랜드 필터 없이 결과만 노출합니다.
        /// 지도 영역 조회로 돌아가면 `false`가 되어 다시 탭과 필터가 있는 목록으로 돌아갑니다.
        var isSearchResultPresented: Bool = false

        var selectedTab: ListTab = .nearby
        var visibleBooths: IdentifiedArrayOf<PhotoBooth> = []
        var favoriteBooths: IdentifiedArrayOf<PhotoBooth> = []
        var visibleFavoriteBooths: IdentifiedArrayOf<PhotoBooth> = []
        var favoriteBoothCount: Int = .zero

        @Shared(.appStorage("NearbyTooltipVisibility")) var isTooltipPresented: Bool = true
    }
    
    public enum Action: BindableAction {
        public enum Delegate {
            case didTapFavorite(PhotoBooth)
            case didTapBrandReorderButton
        }

        // View Actions
        case selectFilterOption(PhotoBoothBrand)
        case selectTab(ListTab)
        case toggleTooltip
        case didTapFavorite(PhotoBooth)
        case didTapBrandReorderButton

        // Internal Actions
        case setBrands(IdentifiedArrayOf<PhotoBoothBrand>)
        case setSearchResultBrandFilters([PhotoBoothSearchBrandFilter]?)
        case clearFilterOptions
        case setVisibleBooths(IdentifiedArrayOf<PhotoBooth>)
        case setFavoriteBooths(IdentifiedArrayOf<PhotoBooth>)
        case setVisibleFavoriteBooths(IdentifiedArrayOf<PhotoBooth>)
        case setFavoriteBoothCount(Int)

        // Delegate Actions
        case didTapBooth(PhotoBooth)
        case delegate(Delegate)

        // Binding Actions
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.analyticsClient) private var analytics
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case let .selectFilterOption(brand):
                let filterAction: MapFilterAction = state.filteredBrands.contains(brand) ? .deselect : .select
                toggleFilterOptionSelection(&state, brand: brand)
                let selectedCount = state.filteredBrands.count
                let event = MapAnalyticsEvent.mapBrandFilterToggle(action: filterAction, selectedCount: selectedCount, brandName: brand.name)
                return .run { _ in await analytics.logEvent(event) }
                
            case let .selectTab(tab):
                state.selectedTab = tab
                return .none

            case .toggleTooltip:
                state.$isTooltipPresented.withLock { $0.toggle() }
                return .none
                
            case let .didTapFavorite(photoBooth):
                return .send(.delegate(.didTapFavorite(photoBooth)))

            case .didTapBrandReorderButton:
                return .send(.delegate(.didTapBrandReorderButton))

            case let .setBrands(brands):
                guard state.brands != brands else { return .none }
                state.brands = brands
                return .none

            case let .setSearchResultBrandFilters(brandFilters):
                state.searchResultBrandFilters = brandFilters
                return .none

            case .clearFilterOptions:
                guard state.filteredBrands.isEmpty == false else { return .none }
                state.filteredBrands.removeAll()
                return .none

            case let .setVisibleBooths(booths):
                state.visibleBooths = booths
                return .none
                
            case let .setFavoriteBooths(booths):
                state.favoriteBooths = booths
                return .none

            case let .setVisibleFavoriteBooths(booths):
                state.visibleFavoriteBooths = booths
                return .none

            case let .setFavoriteBoothCount(count):
                state.favoriteBoothCount = count
                return .none

            default:
                return .none
            }
        }
    }
}


// MARK: - PhotoBoothListFeature + Effect Handlers

private extension PhotoBoothListFeature {
    func toggleFilterOptionSelection(_ state: inout State, brand: PhotoBoothBrand) {
        if state.filteredBrands.contains(brand) {
            state.filteredBrands.remove(brand)
        } else {
            state.filteredBrands.insert(brand)
        }
    }

}
