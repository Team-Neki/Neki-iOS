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
    let store = Store(initialState: AppCoordinator.State.splash(SplashFeature.State())) {
        AppCoordinator()
            ._printChanges()
    }
    
    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(store: store)
        }
    }
}
