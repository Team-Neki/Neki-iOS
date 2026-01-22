//
//  SelectUploadAlbumFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct SelectUploadAlbumFeature {
    
    enum ViewMode: Equatable {
        case prompt       // 초기 선택 팝업 (앨범 없이 / 앨범 선택)
        case albumList    // 앨범 리스트 화면
    }
    
    @ObservableState
    struct State: Equatable {
        let uploadedImageIds: [Int]
        var albums: IdentifiedArrayOf<AlbumItem>
        var selectedAlbumId: UUID? = nil
        
        var viewMode: ViewMode = .prompt
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // User Actions
        case tapUploadWithoutAlbum // 앨범 없이 업로드하기
        case tapSelectAlbumAndUpload // 앨범 선택 후 업로드하기
        
        // Album List Actions
        case tapBackToPrompt // 리스트에서 뒤로가기
        case tapAlbum(UUID) // 앨범 선택
        case tapConfirmUpload // 최종 업로드 버튼
        
        // Delegate
        case delegate(DelegateAction)
        enum DelegateAction {
            case uploadDidSuccess
        }
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                
            // 앨범 없이 최종 업로드
            case .tapUploadWithoutAlbum:
                return .send(.delegate(.uploadDidSuccess))
                
            // 앨범 선택 후 업로드
            case .tapSelectAlbumAndUpload:
                state.viewMode = .albumList
                return .none
                
            // [뒤로가기] 리스트 -> 팝업
            case .tapBackToPrompt:
                state.viewMode = .prompt
                return .none
                
            case let .tapAlbum(id):
                if state.selectedAlbumId == id {
                    state.selectedAlbumId = nil
                } else {
                    state.selectedAlbumId = id
                }
                return .none
                
            // 앨범 리스트 화면에서 최종 업로드
            case .tapConfirmUpload:
                guard let albumId = state.selectedAlbumId else { return .none }
                return .send(.delegate(.uploadDidSuccess))
                
            case .binding:
                return .none
                
            default:
                return .none
            }
        }
    }
}
