//
//  ProfileEditFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/21/26.
//

import ComposableArchitecture
import SwiftUI
import PhotosUI
import os

@Reducer
struct ProfileEditFeature {
    @ObservableState
    struct State {
        @Shared(.appStorage(AppStorageKey.userSessionStatus)) var userSessionStatus: UserSessionStatus = .signedOut
        var nickname: String
        var currentProfileImageURL: URL?
        var selectedProfileImage: UIImage?
        var selectedImageData: Data?
        
        var selectedPickerItem: PhotosPickerItem?
        var isDefaultImageSelected: Bool = false
        
        var doneButtonDisabled: Bool = false
        var isLoading: Bool = false
        let nicknameLengthLimit: Int = 10
        
        var isProfileSelectionAlertPresented: Bool = false
        
        var user: User {
            get {
                guard case let .signedIn(user) = userSessionStatus else { return .dummy }
                return user
            }
            
            set {
                $userSessionStatus.withLock { $0 = .signedIn(newValue) }
            }
        }
        
        init(user: User) {
            nickname = user.nickname
            currentProfileImageURL = user.profileImageURL
        }
    }
    
    enum Action: BindableAction {
        // View Actions
        case openProfileEditAlert
        case closeProfileEditAlert
        case changeToDefaultProfileImage
        case pickerItemChanged(PhotosPickerItem?)
        case imageLoaded(Data?)
        case doneButtonTapped
        
        // Internal & Network Actions
        case updateProfileResponse(Result<User, Error>)
        
        // Binding Actions
        case binding(BindingAction<State>)
    }
    
    private enum CancelID { case imageLoad }
    
    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.authClient) private var authClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .openProfileEditAlert:
                state.isProfileSelectionAlertPresented = true
                return .none
                
            case .closeProfileEditAlert:
                state.isProfileSelectionAlertPresented = false
                return .none
                
            case .changeToDefaultProfileImage:
                state.selectedPickerItem = nil
                state.selectedProfileImage = nil
                state.selectedImageData = nil
                state.currentProfileImageURL = nil
                state.isDefaultImageSelected = true
                state.isProfileSelectionAlertPresented = false
                return .cancel(id: CancelID.imageLoad)
                
            case let .pickerItemChanged(item):
                guard let item else { return .none }
                state.isLoading = true
                
                return .run { send in
                    do {
                        let data = try await item.loadTransferable(type: Data.self)
                        await send(.imageLoaded(data))
                    } catch {
                        Logger.presentation.error("\(#file)-\(#line) Profile Image Load Failed: \(error)")
                        await send(.imageLoaded(nil))
                    }
                }
                .cancellable(id: CancelID.imageLoad, cancelInFlight: true)
            
            case let .imageLoaded(data):
                state.isLoading = false
                guard let data, let image = UIImage(data: data) else { return .none }
                state.selectedImageData = data
                state.selectedProfileImage = image
                state.isDefaultImageSelected = false
                return .none
                
            case .binding(\.nickname):
                state.doneButtonDisabled = (state.nickname.isEmpty || state.nickname.count > state.nicknameLengthLimit) ? true : false
                return .none
                
            case .binding(\.selectedPickerItem):
                return .send(.pickerItemChanged(state.selectedPickerItem))
                
            case .doneButtonTapped:
                guard state.nickname.isEmpty == false, state.nickname.count <= state.nicknameLengthLimit else { return .none }
                
                state.isLoading = true
                state.doneButtonDisabled = true
                let imageAction: ProfileImageUpdateAction = {
                    if let data = state.selectedImageData { return .new(data) }
                    else if state.isDefaultImageSelected { return .delete }
                    else { return .keep }
                }()
                
                return .run { [user = state.user, nickname = state.nickname, imageAction] send in
                    do {
                        let user = try await authClient.updateProfile(nickname: user.nickname == nickname ? nil : nickname, updateAction: imageAction)
                        await send(.updateProfileResponse(.success(user)))
                    } catch {
                        await send(.updateProfileResponse(.failure(error)))
                    }
                }
                
            case let .updateProfileResponse(.success(user)):
                state.isLoading = false
                state.user = user
                return .run { _ in
                    await dismiss()
                }
                
            case let .updateProfileResponse(.failure(error)):
                state.isLoading = false
                state.doneButtonDisabled = false
                Logger.presentation.error("Profile Update Failed: \(error)")
                return .none
                
            default:
                return .none
            }
        }
    }
}
