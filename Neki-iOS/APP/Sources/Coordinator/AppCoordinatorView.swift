//
//  AppCoordinatorView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture

struct AppCoordinatorView: View {
    @Bindable var store: StoreOf<AppCoordinator>
    
    var body: some View {
        Group {
            switch store.route {
            case .auth:
                if let store = store.scope(state: \.route.auth, action: \.route.auth) {
                    LoginCoordinatorView(store: store)
                }
                
            case .mainTab:
                if let store = store.scope(state: \.route.mainTab, action: \.route.mainTab) {
                    MainTabCoordinatorView(store: store)
                }
            }
        }
        .task { await store.send(.onAppLaunched).finish() }
        .onChange(of: store.userSessionStatus) { _, newValue in
            store.send(.userSessionStatusChanged(newValue))
        }
        .nekiToast(item: $store.toastItem)
    }
}
