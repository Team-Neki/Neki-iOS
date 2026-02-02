//
//  MyPageCoordinator.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/20/26.
//

import Foundation
import ComposableArchitecture

@Reducer
struct MyPageCoordinator {
    @ObservableState
    struct State {
        var root: MyPageFeature.State
        var path = StackState<Path.State>()
        
        init(user: User) {
            root = MyPageFeature.State(user: user)
        }
    }
    
    enum Action {
        case root(MyPageFeature.Action)
        case path(StackActionOf<Path>)
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) { MyPageFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case let .root(.cellTapped(cellItem)):
                routeMyPageCellTapped(state: &state, cellItem)
                return .none
                
            case .root(.profileTapped):
                state.path.append(.accountPreference(.init(user: state.root.user)))
                return .none
                
            case .path(.element(id: _, action: .accountPreference(.editProfileButtonTapped))):
                state.path.append(.profileEdit(.init(user: state.root.user)))
                return .none
                
            default:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
    
    private func routeMyPageCellTapped(state: inout State, _ cellItem: MyPageFeature.SectionCellItem) {
        switch cellItem {
        case .deviceAuthorization:
            state.path.append(.deviceAuthorizationPreference(.init()))
            
        case .support:
            // TODO: 노션 등 외부 웹페이지로 이동
            break
        case .termsOfService:
            // TODO: 노션 등 외부 웹페이지로 이동
            break
        case .privacyPolicy:
            // TODO: 노션 등 외부 웹페이지로 이동
            break
        case .version:
            // Version 섹션은 라우팅할 수 있는 셀이 아님
            break
        }
    }
}


// MARK: - MyPageCoordinator + Path

extension MyPageCoordinator {
    @Reducer
    enum Path {
        case deviceAuthorizationPreference(DeviceAuthorizationPreferenceFeature)
        case accountPreference(AccountPreferenceFeature)
        case profileEdit(ProfileEditFeature)
    }
}
