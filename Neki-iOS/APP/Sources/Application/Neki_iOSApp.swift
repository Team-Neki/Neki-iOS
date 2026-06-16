//
//  Neki_iOSApp.swift
//  Neki-iOS
//
//  Created by OneTen on 12/21/25.
//

import SwiftUI
import Combine
import ComposableArchitecture

@main
struct Neki_iOSApp: App {
    @UIApplicationDelegateAdaptor(NekiApplicationDelegate.self) private var applicationDelegate

    let store = Store(initialState: AppCoordinator.State()) {
        AppCoordinator()
    }
    
    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(store: store)
                .onReceive(
                    applicationDelegate.$isAPNSTokenRegistered
                        .removeDuplicates()
                        .filter { $0 }
                ) { _ in
                    store.send(.didRegisterAPNSToken)
                }
                .onOpenURL { handleIncomingURL($0) }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "neki" || url.scheme == "neki-dev" {
            store.send(.onOpenURL(url))
            return
        }
        
        if url.scheme == "https" || url.scheme == "http" {
            guard let host = url.host(), host == "neki.suitestudy.com" else { return }
            return
        }
    }
}
