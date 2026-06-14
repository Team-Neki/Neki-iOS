//
//  DeviceAuthorizationPreferenceView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/20/26.
//

import SwiftUI
import ComposableArchitecture

struct DeviceAuthorizationPreferenceView: View {
    @Bindable var store: StoreOf<DeviceAuthorizationPreferenceFeature>
    
    var body: some View {
        VStack {
            VStack(spacing: 32) {
                settingsSection(title: "권한 설정") {
                    VStack(spacing: 24) {
                        cell(for: .camera, isAuthorized: store.isCameraAuthorized) {
                            store.send(.cameraCellTapped)
                        }
                        
                        cell(for: .location, isAuthorized: store.isLocationAuthorized) {
                            store.send(.locationCellTapped)
                        }
                        
                        cell(for: .photos, isAuthorized: store.isPhotosAuthorized) {
                            store.send(.photosCellTapped)
                        }
                        
                        cell(for: .notifications, isAuthorized: store.isNotificationAuthorized) {
                            store.send(.notificationsCellTapped)
                        }
                    }
                }

                settingsSection(title: "알람 설정") {
                    marketingNotificationToggle
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
        }
        .nekiToolbar {
            NekiToolBar.back { store.send(.dismissButtonTapped) }
        } center: {
            NekiToolBar.textCenter("기기 권한 및 알림")
        }
        .onAppear { store.send(.onAppear) }
    }
}


// MARK: - DeviceAuthorizationPreferenceView + Subviews

private extension DeviceAuthorizationPreferenceView {
    func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .nekiFont(.body14Medium)
                .foregroundStyle(.gray400)

            content()
        }
    }

    var marketingNotificationToggle: some View {
        Toggle(isOn: $store.isMarketingNotificationEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AuthorizationType.marketingNotifications.cellTitle)
                    .nekiFont(.title18Medium)
                    .foregroundStyle(.gray900)

                Text(AuthorizationType.marketingNotifications.cellSubtitle)
                    .nekiFont(.body14Medium)
                    .foregroundStyle(.gray400)
            }
        }
        .toggleStyle(.nekiSwitch)
        .disabled(store.isUpdatingMarketingNotification)
    }

    func cell(for type: AuthorizationType, isAuthorized: Bool, _ onTap: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(type.cellTitle)
                    .nekiFont(.title18Medium)
                    .foregroundStyle(.gray900)
                
                Text(type.cellSubtitle)
                    .nekiFont(.body14Medium)
                    .foregroundStyle(.gray400)
            }
            
            Spacer()
            
            HStack(spacing: .zero) {
                Text(isAuthorized ? "허용됨" : "허용안됨")
                    .nekiFont(.body14Medium)
                    .foregroundStyle(.gray500)
                
                Image(.iconChevronRight)
                    .foregroundStyle(.gray300)
            }
        }
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
    }
}


// MARK: - DeviceAuthorizationPreferenceView + Nested Types

private extension DeviceAuthorizationPreferenceView {
    enum AuthorizationType {
        case camera, location, photos, notifications, marketingNotifications
        
        var cellTitle: String {
            switch self {
            case .camera: return "카메라"
            case .location: return "위치"
            case .photos: return "저장소"
            case .notifications: return "알림"
            case .marketingNotifications: return "혜택·소식 알림"
            }
        }
        
        var cellSubtitle: String {
            switch self {
            case .camera: return "QR 촬영에 필요해요."
            case .location: return "주변 포토부스 탐색에 필요해요."
            case .photos: return "사진 저장 및 업로드에 필요해요."
            case .notifications: return "저장 사진 및 추억 리마인드에 필요해요."
            case .marketingNotifications: return "이벤트, 혜택, 신규 기능 소식 등을 알려드려요."
            }
        }
    }
}

#Preview {
    DeviceAuthorizationPreferenceView(store: .init(initialState: DeviceAuthorizationPreferenceFeature.State(), reducer: { DeviceAuthorizationPreferenceFeature() }))
}
