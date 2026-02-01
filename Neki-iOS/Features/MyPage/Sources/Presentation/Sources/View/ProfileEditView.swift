//
//  ProfileEditView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/21/26.
//

import SwiftUI
import ComposableArchitecture

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused
    @Bindable var store: StoreOf<ProfileEditFeature>
    @State private var isProfileSelectionAlertPresented: Bool = false
    
    var body: some View {
        VStack {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .frame(width: 142, height: 142)
                
                Button {
                    isProfileSelectionAlertPresented = true
                } label: {
                    Image(.iconProfileCamera)
                }
            }
            .padding(.vertical)
            
            CharacterLimitTextField(
                "닉네임",
                text: $store.nickname,
                isFocused: $isFocused,
                prompt: "닉네임을 입력해주세요.",
                limit: store.nicknameLengthLimit
            ).padding(.horizontal)
            
            Spacer()
        }
        .nekiToolbar(
            left: { NekiToolBar.back { dismiss() } },
            center: { NekiToolBar.textCenter("프로필 편집") },
            right: { NekiToolBar.textRight("완료", isEnabled: store.doneButtonDisabled == false) { store.send(.doneButtonTapped) } }
        )
        .nekiSelectAlert(isPresented: $isProfileSelectionAlertPresented, style: .plain, items: ["기본 프로필로 바꾸기", "사진 선택하기"]) {
            // 별도의 onExit 동작 없음
        } onSelect: { index in
            switch index {
            case 0:
                store.send(.changeToDefaultProfileImage)
            case 1:
                store.send(.openPhotosPicker)
            default:
                break
            }
        }
        .contentShape(.rect)
        .onTapGesture { isFocused = false }
    }
}

#Preview {
    ProfileEditView(store: .init(initialState: ProfileEditFeature.State(user: .init(nickname: "변우진", providerType: .apple)), reducer: { ProfileEditFeature() }))
}
