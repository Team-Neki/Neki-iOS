//
//  MainTabCoordinatorView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture
// import Pose
// import Archive

struct MainTabCoordinatorView: View {
    @Bindable var store: StoreOf<MainTabCoordinator>
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $store.selectedTab) {
                Group {
                    // Pose Tab
                    PoseCoordinatorView(store: store.scope(state: \.pose, action: \.pose))
                        .tag(NekiTab.pose)
                    
                    // Archive Tab
                    ArchiveCoordinatorView(store: store.scope(state: \.archive, action: \.archive))
                        .tag(NekiTab.archive)
                    
                    // Map Tab
                    // MyPage Tab
                }
                .toolbar(!store.isTabbarHidden ? .visible : .hidden, for: .tabBar)
            }
            
            if !store.isTabbarHidden {
                NekiTabBar(selectedTab: $store.selectedTab)
            }
        }
        .nekiToast(item: $store.toast)
    }
}

#Preview {
    MainTabCoordinatorView(store: Store(initialState: MainTabCoordinator.State()) {
        MainTabCoordinator()
    }
    )
}
