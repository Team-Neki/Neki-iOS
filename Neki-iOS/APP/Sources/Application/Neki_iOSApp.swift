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
    /// 지금은 개발편의성을 위해 시작점을 메인탭으로 설정
    /// 추후 스플래쉬와 로그인 구현 시 변경
    let store = Store(initialState: AppCoordinator.State.mainTab(MainTabCoordinator.State())) {
        AppCoordinator()
            ._printChanges()
    }
    
    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(store: store)
        }
    }
}
