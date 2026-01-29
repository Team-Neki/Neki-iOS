//
//  AccountPreferenceView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/21/26.
//

import SwiftUI
import ComposableArchitecture

struct AccountPreferenceView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: StoreOf<AccountPreferenceFeature>
    
    @State private var isLogoutAlertPresented: Bool = false
    @State private var isUnregisterAlertPresented: Bool = false
    
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
        .nekiAlert(
            isPresented: $isLogoutAlertPresented,
            style: .cancelable,
            titleMessage: "로그아웃 하시겠습니까?",
            subTitleMessage: "다시 로그인해야 서비스를 이용할 수 있어요.",
            confirmText: "확인",
            cancelText: "취소",
            isProcessing: false, // TODO: 실제 비동기 작업 상태를 주입해야 합니다.
            onConfirm: { store.send(.logoutButtonTapped) },
            onCancel: { isLogoutAlertPresented.toggle() }
        )
        .nekiAlert(
            isPresented: $isUnregisterAlertPresented,
            style: .cancelable,
            titleMessage: "정말 탈퇴하시겠어요?",
            subTitleMessage: "계정을 탈퇴하면 사진과 정보가 모두 삭제되며, 삭제된 데이터는 복구할 수 없어요.",
            confirmText: "탈퇴 확정",
            cancelText: "취소",
            isProcessing: false, // TODO: 여기도 마찬가지로 실제 작업 상태 주입
            onConfirm: { store.send(.unregisterButtonTapped) },
            onCancel: { isUnregisterAlertPresented.toggle() }
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
            Circle() // TODO: 실제 프로필 이미지 주입되어야 함
                .frame(width: 142, height: 142)
            
            HStack(spacing: 9) {
                // TODO: 실제 유저 정보가 주입되어야 함
                Text("닉네임")
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
                .nekiFont(.body16Medium)
                .foregroundStyle(.gray900)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { isLogoutAlertPresented.toggle() }
            
            Text("탈퇴하기")
                .nekiFont(.body16Medium)
                .foregroundStyle(.gray900)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { isUnregisterAlertPresented.toggle() }
        }
        .padding(.horizontal)
    }
}
