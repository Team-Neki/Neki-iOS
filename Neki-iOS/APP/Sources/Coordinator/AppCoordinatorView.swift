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
        switch store.state {
        case .splash:
            if let store = store.scope(state: \.splash, action: \.splash) {
                SplashView(store: store)
              }
        case .auth:
            if let store = store.scope(state: \.auth, action: \.auth) {
                LoginCoordinatorView(store: store)
              }
            
        case .mainTab:
            if let store = store.scope(state: \.mainTab, action: \.mainTab) {
                MainTabCoordinatorView(store: store)
              }
        }
    }
}
