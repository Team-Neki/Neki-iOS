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
        let brands = PhotoBoothBrand.allCases
        var filteredBrands: Set<PhotoBoothBrand> = []
        
        var photoBooths: IdentifiedArrayOf<PhotoBooth> = []
        var visibleBooths: IdentifiedArrayOf<PhotoBooth> = []
        
        var isWarningAlertPresented: Bool = false
    }
    
    public enum Action: BindableAction {
        // View Actions
        case selectFilterOption(PhotoBoothBrand)
        case showWarningAlert
        case dismissWarningAlert
        
        // Delegate Actions
        case didTapBooth(PhotoBooth)
        
        // Binding Actions
        case binding(BindingAction<State>)
    }
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case let .selectFilterOption(brand):
                toggleFilterOptionSelection(&state, brand: brand)
                return .none
                
            case .showWarningAlert:
                state.isWarningAlertPresented = true
                return .none
                
            case .dismissWarningAlert:
                state.isWarningAlertPresented = false
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
