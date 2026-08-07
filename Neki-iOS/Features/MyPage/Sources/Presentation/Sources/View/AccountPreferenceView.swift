//
//  AccountPreferenceView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/21/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct AccountPreferenceView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: StoreOf<AccountPreferenceFeature>
    
    var body: some View {
        VStack {
            profileArea
            
            divider
            
            accountManageArea
            
            Spacer()
        }
        .nekiToolbar(
            left: { NekiToolBar.back(action: { dismiss() }) },
            center: { NekiToolBar.textCenter("계정 설정") }
        )
        .nekiLoading(isPresented: store.isLoading)
        .nekiAlert(
            isPresented: $store.isLogoutAlertPresented,
            style: .cancelable,
            title: "로그아웃 하시겠습니까?",
            subtitle: "다시 로그인해야 서비스를 이용할 수 있어요.",
            confirmText: "확인",
            cancelText: "취소",
            isProcessing: false,
            hasIcon: false,
            onConfirm: { store.send(.logoutButtonTapped) },
            onCancel: { store.send(.cancelButtonTapped) }
        )
        .nekiAlert(
            isPresented: $store.isUnregisterAlertPresented,
            style: .cancelable,
            title: "정말 탈퇴하시겠어요?",
            subtitle: "계정을 탈퇴하면 사진과 정보가 모두 삭제되며, 삭제된 데이터는 복구할 수 없어요.",
            confirmText: "탈퇴 확정",
            cancelText: "취소",
            isProcessing: false,
            hasIcon: false,
            onConfirm: { store.send(.unregisterButtonTapped) },
            onCancel: { store.send(.cancelButtonTapped) }
        )
    }
}


// MARK: - AccountPreferenceView + Subviews

private extension AccountPreferenceView {
    var divider: some View {
        Rectangle()
            .frame(height: 11)
            .foregroundStyle(.gray25)
    }
    
    var profileArea: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                KFImage(store.user.profileImageURL)
                    .resizable()
                    .onFailureImage(.iconDefaultProfile)
                    .scaledToFill()
                    .frame(width: 142, height: 142)
                    .clipShape(.circle)
                
                Button {
                    store.send(.editProfileButtonTapped)
                } label: {
                    Image(.iconProfileCamera)
                }
            }
            
            HStack(spacing: 9) {
                Text(store.user.nickname)
                    .nekiFont(.title20Medium)
                    .foregroundStyle(.gray900)
                
                Image(.iconPencil)
                    .onTapGesture { store.send(.editProfileButtonTapped) }
            }
        }
        .padding()
    }
    
    var accountManageArea: some View {
        VStack(spacing: 4) {
            Text("서비스 정보 및 지원")
                .nekiFont(.caption12Medium)
                .foregroundStyle(.gray400)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("로그아웃")
                .nekiFont(.title18Medium)
                .foregroundStyle(.gray900)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { store.send(.logoutMenuTapped) }
            
            Text("탈퇴하기")
                .nekiFont(.title18Medium)
                .foregroundStyle(.gray900)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { store.send(.unregisterMenuTapped) }
        }
        .padding(.horizontal)
    }
}
