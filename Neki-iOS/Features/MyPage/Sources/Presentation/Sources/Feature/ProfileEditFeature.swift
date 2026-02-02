//
//  ProfileEditFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/21/26.
//

import UIKit
import ComposableArchitecture

@Reducer
struct ProfileEditFeature {
    @ObservableState
    struct State {
        var nickname: String
        var currentProfileImageURL: URL?
        var selectedProfileImage: UIImage?
        var doneButtonDisabled: Bool = false
        let nicknameLengthLimit: Int = 10
        
        init(user: User) {
            nickname = user.nickname
            currentProfileImageURL = user.profileImageURL
        }
    }
    
    enum Action: BindableAction {
        // View Actions
        case changeToDefaultProfileImage
        case openPhotosPicker
        case doneButtonTapped
        
        // Binding Actions
        case binding(BindingAction<State>)
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .changeToDefaultProfileImage:
                state.selectedProfileImage = nil
                state.currentProfileImageURL = nil
                return .none
                
            case .openPhotosPicker:
                // TODO: PhotosUI PhotoPicker 열기
                return .none
                
            case .binding(\.nickname):
                guard state.nickname.isEmpty == false, state.nickname.count < state.nicknameLengthLimit else {
                    state.doneButtonDisabled = true
                    return .none
                }
                state.doneButtonDisabled = false
                return .none
                
            case .doneButtonTapped:
                return .none
                
            default:
                return .none
            }
        }
    }
}
