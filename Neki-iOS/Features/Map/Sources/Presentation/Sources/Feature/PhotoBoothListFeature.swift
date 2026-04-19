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
    @ObservableState
    public struct State {
        var brands: IdentifiedArrayOf<PhotoBoothBrand> = []
        var filteredBrands: Set<PhotoBoothBrand> = []
        
        var photoBooths: IdentifiedArrayOf<PhotoBooth> = []
        var visibleBooths: IdentifiedArrayOf<PhotoBooth> = []
        
        @Shared(.appStorage("NearbyTooltipVisibility")) var isTooltipPresented: Bool = true
    }
    
    public enum Action: BindableAction {
        // View Actions
        case selectFilterOption(PhotoBoothBrand)
        case toggleTooltip
        
        // Internal Actions
        case setNearbyBooths(IdentifiedArrayOf<PhotoBooth>)
        case setVisibleBooths(IdentifiedArrayOf<PhotoBooth>)
        
        // Delegate Actions
        case didTapBooth(PhotoBooth)
        
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
                
            case .toggleTooltip:
                state.$isTooltipPresented.withLock { $0.toggle() }
                return .none
                
            case let .setNearbyBooths(booths):
                state.photoBooths = booths
                return .none
                
            case let .setVisibleBooths(booths):
                state.visibleBooths = booths
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
