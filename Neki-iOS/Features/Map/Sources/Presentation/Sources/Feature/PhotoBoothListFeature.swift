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
            case .nearby: return "가까운 포토부스"
            case .favorite: return "저장한 포토부스"
            }
        }

        func title(currentMapRegionTitle: String) -> String {
            switch self {
            case .nearby: return currentMapRegionTitle
            case .favorite: return title
            }
        }
    }

    @ObservableState
    public struct State {
        var brands: IdentifiedArrayOf<PhotoBoothBrand> = []
        var nearbyBrands: IdentifiedArrayOf<PhotoBoothBrand> = []
        var availableNearbyBrandIDs: Set<PhotoBoothBrand.ID> = []
        var filteredBrands: Set<PhotoBoothBrand> = []
        var displayedBrands: IdentifiedArrayOf<PhotoBoothBrand> { selectedTab == .nearby ? nearbyBrands : brands }
        
        var selectedTab: ListTab = .nearby
        /// 현재 지도 카메라가 가리키는 지역으로, 선택된 목록 탭과 독립적으로 유지됩니다.
        var currentMapAddress: AdministrativeAddress?
        var currentMapRegionTitle: String {
            guard let currentMapAddress else { return ListTab.nearby.title }
            let areaNames = currentMapAddress.displayAreas(using: .southKorea).map(\.name)
            guard areaNames.isEmpty == false else { return ListTab.nearby.title }
            return areaNames.joined(separator: " ")
        }
        var photoBooths: IdentifiedArrayOf<PhotoBooth> = []
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
        case setAvailableNearbyBrandIDs(Set<PhotoBoothBrand.ID>)
        case clearFilterOptions
        case setNearbyBooths(IdentifiedArrayOf<PhotoBooth>)
        case setCurrentMapAddress(AdministrativeAddress?)
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
                updateNearbyBrands(&state)
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
                updateNearbyBrands(&state)
                return .none

            case let .setAvailableNearbyBrandIDs(brandIDs):
                guard state.availableNearbyBrandIDs != brandIDs else { return .none }
                state.availableNearbyBrandIDs = brandIDs
                updateNearbyBrands(&state)
                return .none

            case .clearFilterOptions:
                guard state.filteredBrands.isEmpty == false else { return .none }
                state.filteredBrands.removeAll()
                updateNearbyBrands(&state)
                return .none

            case let .setNearbyBooths(booths):
                state.photoBooths = booths
                return .none

            case let .setCurrentMapAddress(address):
                // 선택된 목록 탭과 무관하게 현재 지도 지역을 갱신합니다.
                state.currentMapAddress = address
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

    func updateNearbyBrands(_ state: inout State) {
        var displayedBrandIDs = state.availableNearbyBrandIDs
        displayedBrandIDs.reserveCapacity(displayedBrandIDs.count + state.filteredBrands.count)
        state.filteredBrands.forEach { displayedBrandIDs.insert($0.id) }
        let nearbyBrands = state.brands.filter { displayedBrandIDs.contains($0.id) }
        guard state.nearbyBrands != nearbyBrands else { return }
        state.nearbyBrands = nearbyBrands
    }
}
