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
    }

    @ObservableState
    public struct State {
        var brands: IdentifiedArrayOf<PhotoBoothBrand> = []
        var filteredBrands: Set<PhotoBoothBrand> = []
        
        var selectedTab: ListTab = .nearby
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
        case setNearbyBooths(IdentifiedArrayOf<PhotoBooth>)
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
                return .run { _ in analytics.logEvent(event: event) }
                
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

            case let .setNearbyBooths(booths):
                state.photoBooths = booths
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
