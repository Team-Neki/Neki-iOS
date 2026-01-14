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
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            
            // Pose Tab
            PoseCoordinatorView(store: store.scope(state: \.pose, action: \.pose))
                .tabItem {
                    Label("포즈", systemImage: "figure.stand")
                }
                .tag(MainTabCoordinator.Tab.pose)
            
            // Archive Tab
            ArchiveCoordinatorView(store: store.scope(state: \.archive, action: \.archive))
                .tabItem {
                    Label("보관함", systemImage: "archivebox")
                }
                .tag(MainTabCoordinator.Tab.archive)
            
            // Map Tab
            // MyPage Tab
        }
        .tint(.black)
    }
}
