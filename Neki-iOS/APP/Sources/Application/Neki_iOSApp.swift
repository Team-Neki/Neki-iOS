//
//  Neki_iOSApp.swift
//  Neki-iOS
//
//  Created by OneTen on 12/21/25.
//

import SwiftUI
import ComposableArchitecture
import Firebase

@main
struct Neki_iOSApp: App {
    let store = Store(initialState: AppCoordinator.State()) {
        AppCoordinator()
    }
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(store: store)
                .onOpenURL { handleIncomingURL($0) }
        }
    }
}

private extension Neki_iOSApp {
    func handleIncomingURL(_ url: URL) {
        if url.scheme == "neki" { return }
        
        if url.scheme == "https" || url.scheme == "http" {
            guard let host = url.host(), host == "neki.suitestudy.com" else { return }
            return
        }
    }
}
