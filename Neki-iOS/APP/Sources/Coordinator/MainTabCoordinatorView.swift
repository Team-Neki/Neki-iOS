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
            Group {
                switch store.selectedTab {
                case .archive:
                    ArchiveCoordinatorView(store: store.scope(state: \.archive, action: \.archive))
                
                case .pose:
                    PoseCoordinatorView(store: store.scope(state: \.pose, action: \.pose))
                    
                case .map:
                    MapCoordinatorView(store: store.scope(state: \.map, action: \.map))

                case .myPage:
                    MyPageCoordinatorView(store: store.scope(state: \.myPage, action: \.myPage))
                }
            }
            
            if !store.isTabbarHidden {
                NekiTabBar(selectedTab: $store.selectedTab)
            }
        }
        .nekiToast(item: $store.toast)
        
        // TODO: - 탭 이동 시 화면 초기화 되는지 기디 물어보기. 그리고 탭 한 번 더 누르면 초기화면으로 가는지도
    }
}

#Preview {
    MainTabCoordinatorView(store: Store(initialState: MainTabCoordinator.State()) {
        MainTabCoordinator()
    }
    )
}
