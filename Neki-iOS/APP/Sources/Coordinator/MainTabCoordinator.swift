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
        var selectedTab: NekiTab = .archive
        
        // 하위 코디네이터들의 State를 보유
        var pose = PoseCoordinator.State()
        var archive = ArchiveCoordinator.State()
        
        var isTabbarHidden: Bool = false
        
        // 토스트메세지 상태
        var toast: NekiToastItem? = nil
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
                
                // 아카이브뷰에서 토스트 메세지 띄움
            case let .archive(.delegate(.showToast(item))):
                state.toast = item
                return .none
                
            case .pose(.delegate(.logout)):
                return .send(.delegate(.logout))
                
            default:
                return .none
            }
        }
        
        /// 피그마 확인 결과 탭바가 사라지는 모든 case는 depth가 1 이상일 경우더라구요
        /// 즉, 메인 홈 화면에서 depth가 추가되어 넘어가는 뷰들은 전부 탭바가 사라집니다.
        /// 그래서 각 Feature의 state에서 path에 하나라도 추가될 경우 탭바를 가리게 설계했습니다.
        /// 한 가지 문제는, 나중에 depth가 추가되어도 탭바가 보여져야 하는 경우가 생긴다면 다시 머리 싸매야함
        Reduce { state, action in
            switch state.selectedTab {
            case .archive:
                state.isTabbarHidden = !state.archive.path.isEmpty
                
            case .pose:
                state.isTabbarHidden = !state.pose.path.isEmpty
                
            default:
                state.isTabbarHidden = false
            }
            return .none
        }
        
    }
    
}
