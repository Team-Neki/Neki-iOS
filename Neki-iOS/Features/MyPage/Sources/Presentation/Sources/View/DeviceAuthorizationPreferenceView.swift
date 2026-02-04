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
            Section {
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
                    
                    // TODO: 알림 기능부터 구현 필요
//                    cell(for: .notifications, isAuthorized: true) {
//                        <#code#>
//                    }
                }
            } header: {
                Text("권한 설정")
                    .nekiFont(.caption12Medium)
                    .foregroundStyle(.gray400)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
        }
        .nekiToolbar {
            NekiToolBar.back { store.send(.dismissButtonTapped) }
        } center: {
            NekiToolBar.textCenter("기기 권한")
        }
        .nekiAlert(
            isPresented: $store.isAlertPresented,
            style: .cancelable,
            title: store.alertItem?.title ?? "권한 안내",
            subtitle: store.alertItem?.description ?? "원활한 서비스 제공을 위해 권한을 허용해주세요.",
            confirmText: "허용",
            cancelText: "취소",
            hasIcon: true,
            onConfirm: { store.send(.openAppSettings) },
            onCancel: { store.send(.alertDismissed) }
        )
        .onAppear { store.send(.onAppear) }
    }
}


// MARK: - DeviceAuthorizationPreferenceView + Subviews

private extension DeviceAuthorizationPreferenceView {
    func cell(for type: AuthorizationType, isAuthorized: Bool, _ onTap: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(type.cellTitle)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
                
                Text(type.cellSubtitle)
                    .nekiFont(.caption12Medium)
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
        case camera, location, photos, notifications
        
        var cellTitle: String {
            switch self {
            case .camera: return "카메라"
            case .location: return "위치"
            case .photos: return "저장소"
            case .notifications: return "알림"
            }
        }
        
        var cellSubtitle: String {
            switch self {
            case .camera: return "QR 촬영에 필요해요."
            case .location: return "주변 포토부스 탐색에 필요해요."
            case .photos: return "사진 저장 및 업로드에 필요해요."
            case .notifications: return "저장 사진 및 추억 리마인드에 필요해요."
            }
        }
    }
}

#Preview {
    DeviceAuthorizationPreferenceView(store: .init(initialState: DeviceAuthorizationPreferenceFeature.State(), reducer: { DeviceAuthorizationPreferenceFeature() }))
}
