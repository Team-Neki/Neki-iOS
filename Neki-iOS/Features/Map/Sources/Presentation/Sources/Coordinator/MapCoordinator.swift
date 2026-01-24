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
    }
}
