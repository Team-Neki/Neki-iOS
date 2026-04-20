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
        @Shared(.appStorage(AppStorageKey.userSessionStatus)) var userSessionStatus: UserSessionStatus = .signedOut
        
        var root = MyPageFeature.State()
        var path = StackState<Path.State>()
    }
    
    enum Action {
        case root(MyPageFeature.Action)
        case path(StackActionOf<Path>)
        
        case delegate(Delegate)
        enum Delegate {
            case didLogout
            case didWithdraw
        }
    }
    
    @Dependency(\.openURL) private var openURL
    
    var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) { MyPageFeature() }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case let .root(.cellTapped(cellItem)):
                return routeMyPageCellTapped(state: &state, cellItem)
                
            case .root(.profileTapped):
                state.path.append(.accountPreference(.init()))
                return .none
                
            case .path(.element(id: _, action: .accountPreference(.editProfileButtonTapped))):
                guard case let .signedIn(user) = state.userSessionStatus else { return .none }
                state.path.append(.profileEdit(.init(user: user)))
                return .none
                
            case .path(.element(id: _, action: .accountPreference(.didSignOut))):
                return .send(.delegate(.didLogout))
                
            case .path(.element(id: _, action: .accountPreference(.didWithdraw))):
                return .send(.delegate(.didWithdraw))
                
            default:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
    
    private func routeMyPageCellTapped(state: inout State, _ cellItem: MyPageFeature.SectionCellItem) -> Effect<Action> {
        switch cellItem {
        case .deviceAuthorization:
            state.path.append(.deviceAuthorizationPreference(.init()))
            return .none
            
        case .support:
            return .run { _ in
                guard let url = URL(string: "https://tally.so/r/obGpRX") else { return }
                await openURL(url)
            }
            
        case .termsOfService:
            return .run { _ in
                guard let url = URL(string: "https://lydian-tip-26b.notion.site/2ee0d9441db0807c8684ce3e2d4b8aca?source=copy_link") else { return }
                await openURL(url)
            }
            
        case .privacyPolicy:
            return .run { _ in
                guard let url = URL(string: "https://lydian-tip-26b.notion.site/2ee0d9441db0807cb850f78145db6dd3?pvs=74") else { return }
                await openURL(url)
            }
            
        case .version:
            return .none
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
