//
//  MainTabCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture
// import Pose
// import Archive

@Reducer
struct MainTabCoordinator {
    
    @ObservableState
    struct State {
        var selectedTab: Tab = .archive
        
        // 하위 코디네이터들의 State를 보유
        var pose = PoseCoordinator.State()
        var archive = ArchiveCoordinator.State()
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case pose(PoseCoordinator.Action)
        case archive(ArchiveCoordinator.Action)
        
        // 상위 코디네이터(AppCoordinator)로 보낼 신호
        case delegate(Delegate)
        enum Delegate {
            case logout
        }
    }
    
    enum Tab: Hashable {
        case pose
        case archive
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.pose, action: \.pose) {
            PoseCoordinator()
        }
        
        Scope(state: \.archive, action: \.archive) {
            ArchiveCoordinator()
        }
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
                // 아카이브 내부 뷰에서 포즈 내부 뷰로 변경 (피쳐간 이동)
            case let .archive(.delegate(.requestJumpToPose(item))):
                state.selectedTab = .pose
                return .send(.pose(.routeToDetail(item)))
                
            case .pose(.delegate(.logout)):
                return .send(.delegate(.logout))
                
            default:
                return .none
            }
        }
    }
    
}
