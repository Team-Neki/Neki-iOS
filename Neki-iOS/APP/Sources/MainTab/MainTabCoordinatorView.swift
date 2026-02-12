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
                    
                case .qrScan:
                    EmptyView()
                    
                case .map:
                    MapCoordinatorView(store: store.scope(state: \.map, action: \.map))

                case .myPage:
                    MyPageCoordinatorView(store: store.scope(state: \.myPage, action: \.myPage))
                }
            }
            
            if !store.isTabbarHidden {
                NekiTabBar(selectedTab: $store.selectedTab) { store.send(.onTapQRScan) }
            }
        }
        .nekiToast(item: $store.toast)
        .fullScreenCover(item: $store.scope(state: \.qrScan, action: \.qrScan)) { qrStore in
            QRCodeScannerView(store: qrStore)
        }
        .nekiAlert(
            isPresented: $store.isPermissionAlertPresented,
            style: .cancelable,
            title: "카메라 권한",
            subtitle: "QR 인식을 위해 카메라 접근이 필요해요",
            confirmText: "허용",
            cancelText: "취소",
            onConfirm: { store.send(.openAppSettings) },
            onCancel: { store.send(.dismissPermissionAlert) }
        )
    }
}
