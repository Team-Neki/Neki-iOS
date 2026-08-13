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
        .nekiLoading(
            isPresented: store.imagePicker.isLoading,
            message: "사진을 불러오고 있어요."
        )
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: store.selectedTab) { _, newTab in
            store.send(.tabChanged(newTab))
        }
        .nekiToast(item: $store.toast)
        .modifier(MarketingConsentAlertModifier(store: store))
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
        .nekiAlert(
            isPresented: $store.isPushNotificationPermissionAlertPresented,
            style: .cancelable,
            title: "알림이 꺼져있어요.",
            subtitle: "네키 알림을 받으려면\n기기 설정에서 알림 권한을 허용해주세요.",
            confirmText: "설정으로 이동",
            cancelText: "나중에",
            onConfirm: { store.send(.openAppSettings) },
            onCancel: { store.send(.dismissPushNotificationPermissionAlert) }
        )
        .sheet(isPresented: Binding($store.scope(state: \.$destination, action: \.destination).uploadSelection)) {
            store.send(.uploadSelectionSheetDismissed)
        } content: {
            UploadSelectionSheet(store: store)
        }
        .fullScreenCover(item: $store.scope(state: \.$destination, action: \.destination).qrScan) { qrStore in
            QRCodeScannerView(store: qrStore)
        }
        .fullScreenCover(item: $store.scope(state: \.$destination, action: \.destination).notificationList) { notificationStore in
            PushNotificationListCoordinatorView(store: notificationStore)
        }
        .photosPicker(
            isPresented: $store.isPhotoPickerPresented.sending(\.setPhotosPickerPresented),
            selection: $store.imagePicker.pickerItems.sending(\.imagePicker.pickerItemsChanged),
            maxSelectionCount: store.imagePicker.remainingCount,
            matching: .images
        )
    }
}


// MARK: - MarketingConsentAlertModifier

private struct MarketingConsentAlertModifier: ViewModifier {
    @Bindable var store: StoreOf<MainTabCoordinator>

    func body(content: Content) -> some View {
        content.nekiAlert(
            isPresented: $store.isMarketingConsentAlertPresented,
            style: .cancelable,
            contentStyle: .marketingConsent(description: description),
            title: "놓치지 마세요!",
            subtitle: "네키의 이벤트, 혜택 프로모션,\n신규 업데이트 소식을 선별해서 알려드려요.",
            confirmText: "네, 알려주세요",
            cancelText: "괜찮아요",
            isProcessing: store.isUpdatingMarketingConsent,
            hasIcon: true,
            onConfirm: { store.send(.updateMarketingConsent(true)) },
            onCancel: { store.send(.updateMarketingConsent(false)) },
            onDismiss: { store.send(.dismissMarketingConsentAlert) }
        )
    }

    private var description: Text {
        Text("마케팅 정보 푸시 수신 동의 여부는 ")
            .foregroundColor(.gray400)
        + Text("마이페이지 >\n권한 설정 > 알림 설정")
            .foregroundColor(.primary500)
        + Text("에서 변경 가능해요.")
            .foregroundColor(.gray400)
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
