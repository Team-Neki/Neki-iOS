//
//  MainTabCoordinatorView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/15/26.
//

import SwiftUI
import ComposableArchitecture
import PhotosUI
// import Pose
// import Archive

struct MainTabCoordinatorView: View {
    @Bindable var store: StoreOf<MainTabCoordinator>
    @State private var sheetHeight: CGFloat = 1
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch store.selectedTab {
                case .archive:
                    ArchiveCoordinatorView(store: store.scope(state: \.archive, action: \.archive))
                
                case .pose:
                    PoseCoordinatorView(store: store.scope(state: \.pose, action: \.pose))
                    
                case .add:
                    EmptyView()
                    
                case .map:
                    MapCoordinatorView(store: store.scope(state: \.map, action: \.map))

                case .myPage:
                    MyPageCoordinatorView(store: store.scope(state: \.myPage, action: \.myPage))
                }
            }
            
            if !store.isTabbarHidden {
                NekiTabBar(selectedTab: $store.selectedTab) { store.send(.onTapAddButton) }
            }
        }
        .nekiToast(item: $store.toast)
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
        .sheet(item: $store.scope(state: \.destination?.uploadSelection, action: \.destination.uploadSelection)) {
            store.send(.uploadSelectionSheetDismissed)
        } content: { _ in
            UploadSelectionSheet(store: store)
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.qrScan, action: \.destination.qrScan)) { qrStore in
            QRCodeScannerView(store: qrStore)
        }
        .photosPicker(
            isPresented: $store.isPhotoPickerPresented.sending(\.setPhotosPickerPresented),
            selection: $store.imagePicker.pickerItems.sending(\.imagePicker.pickerItemsChanged),
            maxSelectionCount: store.imagePicker.remainingCount,
            matching: .images
        )
    }
}


// MARK: - Subviews

extension MainTabCoordinatorView {
    struct UploadSelectionSheet: View {
        @Bindable var store: StoreOf<MainTabCoordinator>
        @State private var sheetHeight: CGFloat = 1
        
        var body: some View {
            VStack(spacing: 4) {
                Capsule()
                    .frame(width: 45, height: 4)
                    .padding(.horizontal, 165)
                    .padding(.vertical, 10)
                    .foregroundStyle(.gray100)
                
                VStack(alignment: .leading, spacing: 24) {
                    Text("네컷사진 추가")
                        .nekiFont(.title20SemiBold)
                        .foregroundStyle(.gray900)
                    
                    HStack(spacing: 36) {
                        Button {
                            store.send(.onTapQRScan)
                        } label: {
                            VStack(spacing:  8) {
                                Image(.iconAddQr)
                                Text("QR로 추가")
                            }
                        }
                        
                        Button {
                            store.send(.onTapGallery)
                        } label: {
                            VStack(spacing:  8) {
                                Image(.iconAddGallery)
                                Text("갤러리에서 추가")
                            }
                        }
                    }
                    .nekiFont(.body14Medium)
                    .foregroundStyle(.gray700)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .safeAreaPadding(.bottom)
            .presentationBackground(.white)
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
            .autoSizingDetent($sheetHeight)
        }
    }
}
