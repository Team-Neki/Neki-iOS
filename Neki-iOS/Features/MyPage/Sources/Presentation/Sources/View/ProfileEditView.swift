//
//  ProfileEditView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/21/26.
//

import SwiftUI
import PhotosUI
import ComposableArchitecture
import Kingfisher

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused
    @Bindable var store: StoreOf<ProfileEditFeature>
    @State private var isProfileSelectionAlertPresented: Bool = false
    
    var body: some View {
        ZStack {
            VStack {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let selectedImage = store.selectedProfileImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            KFImage(store.currentProfileImageURL)
                                .resizable()
                                .onFailureImage(.iconDefaultProfile)
                                .scaledToFill()
                        }
                    }
                    .frame(width: 142, height: 142)
                    .clipShape(.circle)
                    
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
            
            if store.isLoading { ProgressView().controlSize(.large) }
        }
        .disabled(store.isLoading)
        .nekiToolbar(
            left: { NekiToolBar.back { dismiss() } },
            center: { NekiToolBar.textCenter("프로필 편집") },
            right: { NekiToolBar.textRight("완료", isEnabled: store.doneButtonDisabled == false) { store.send(.doneButtonTapped) } }
        ).nekiSelectAlert(isPresented: $isProfileSelectionAlertPresented) {
            // 별도의 onExit 동작 없음
        } content: {
            VStack(spacing: 4) {
                Button {
                    store.send(.changeToDefaultProfileImage)
                } label: {
                    Text("기본 프로필로 바꾸기")
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 10)
                
                PhotosPicker(selection: $store.selectedPickerItem, matching: .images, photoLibrary: .shared()) {
                    Text("사진 선택하기")
                        .padding(.vertical, 14)
                        .padding(.horizontal, 10)
                }
                .onChange(of: store.selectedPickerItem) { _, newValue in
                    guard newValue != nil else { return }
                    isProfileSelectionAlertPresented = false
                }
            }
        }
        .padding(.vertical, 12)
        .nekiFont(.body16SemiBold)
        .foregroundStyle(.gray800)
        .contentShape(.rect)
        .onTapGesture { isFocused = false }
    }
}

#Preview {
    ProfileEditView(store: .init(initialState: ProfileEditFeature.State(user: .init(id: 1, nickname: "swain", email: nil, profileImageURL: nil, providerType: .apple)), reducer: { ProfileEditFeature() }))
}
