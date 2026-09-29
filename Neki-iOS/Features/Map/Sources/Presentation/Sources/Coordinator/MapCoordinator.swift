//
//  MapCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import Foundation
import ComposableArchitecture

@Reducer
struct MapCoordinator {
    
    @ObservableState
    struct State {
        var root = MapFeature.State()
        var path = StackState<Path.State>()

        /// 탭바를 가려야 하는지 여부입니다.
        ///
        /// 하위 화면으로 들어갔거나 검색 화면을 띄운 동안에는 탭바를 가립니다.
        /// 검색 화면은 지도 위에 겹쳐 그리므로 지도 밖에서 그리는 탭바를 따로 가려야 합니다.
        var hidesTabBar: Bool { !path.isEmpty || root.isSearchPresented }
    }
    
    enum Action {
        case root(MapFeature.Action)
        case path(StackActionOf<Path>)
        
        case delegate(Delegate)
        // 상위 코디네이터(MainTab)로 보낼 신호
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) {
            MapFeature()
        }
        
        Reduce { state, action in
            /// 화면전환과 관련된 액션 case만 사용하고 나머지는 default를 이용해 무시
            switch action {
            case let .root(.delegate(.showToast(item))):
                return .send(.delegate(.showToast(item)))

            case let .root(.delegate(.routeToBrandReorder(brands))):
                state.path.append(.brandReorder(PhotoBoothBrandReorderFeature.State(brands: brands)))
                return .none

            case let .path(.element(_, action: .brandReorder(.delegate(.saveCompleted(brands))))):
                state.path.removeLast()
                return .concatenate(
                    .send(.root(.photoBoothListAction(.setBrands(brands)))),
                    .send(.root(.startBackgroundCalculation))
                )

            case .path(.element(_, action: .brandReorder(.delegate(.dismiss)))):
                state.path.removeLast()
                return .none
                
            default:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension MapCoordinator {
    @Reducer
    enum Path {
        case brandReorder(PhotoBoothBrandReorderFeature)
    }
}
