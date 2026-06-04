//
//  PhotoBoothBrandReorderFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/4/26.
//

import Foundation
import ComposableArchitecture

@Reducer
public struct PhotoBoothBrandReorderFeature {
    @ObservableState
    public struct State {
        var initialBrands: IdentifiedArrayOf<PhotoBoothBrand>
        var brands: IdentifiedArrayOf<PhotoBoothBrand>
        var isSaving: Bool = false

        var isDoneButtonEnabled: Bool { isSaving == false && brands.map(\.id) != initialBrands.map(\.id) }

        public init(brands: IdentifiedArrayOf<PhotoBoothBrand>) {
            self.initialBrands = brands
            self.brands = brands
        }
    }

    public enum Action {
        public enum Delegate {
            case dismiss
            case saveCompleted(IdentifiedArrayOf<PhotoBoothBrand>)
        }

        case didTapBackButton
        case moveBrands(IndexSet, Int)
        case didTapDoneButton
        case saveResponse(Result<[PhotoBoothBrand], Error>)
        case delegate(Delegate)
    }

    @Dependency(\.photoBoothClient) private var photoBoothClient
    
    public var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .didTapBackButton:
                return .send(.delegate(.dismiss))

            case let .moveBrands(source, destination):
                state.brands.move(fromOffsets: source, toOffset: destination)
                return .none

            case .didTapDoneButton:
                guard state.isDoneButtonEnabled else { return .none }
                state.isSaving = true
                let reorderedBrands = state.brands
                return .run { send in
                    await send(.saveResponse(Result { try await photoBoothClient.updateBrandOrder(Array(reorderedBrands)) }))
                }

            case let .saveResponse(.success(brands)):
                state.isSaving = false
                let orderedBrands = IdentifiedArray(uniqueElements: brands)
                state.initialBrands = orderedBrands
                state.brands = orderedBrands
                return .send(.delegate(.saveCompleted(orderedBrands)))

            case .saveResponse(.failure):
                state.isSaving = false
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
