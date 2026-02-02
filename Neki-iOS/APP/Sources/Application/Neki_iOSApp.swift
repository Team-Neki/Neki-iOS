//
//  Neki_iOSApp.swift
//  Neki-iOS
//
//  Created by OneTen on 12/21/25.
//

import SwiftUI
import ComposableArchitecture

@main
struct Neki_iOSApp: App {
//    let store = Store(initialState: AppCoordinator.State.splash(.init())) {
//        AppCoordinator()
//    }
    let store = Store(initialState: MainTabCoordinator.State.init(user: User(id: 1, nickname: "testuser", email: nil, profileImageURL: nil, providerType: .apple))) {
        MainTabCoordinator()
    }
    
    var body: some Scene {
        WindowGroup {
//            AppCoordinatorView(store: store)
            MainTabCoordinatorView(store: store)
        }
    }
}
