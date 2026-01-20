//
//  ArchivePhotoDetailFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct ArchivePhotoDetailFeature {
    @ObservableState
    struct State {
        @Shared var photos: IdentifiedArrayOf<ArchiveImageItem>
        let itemID: UUID
        
        var item: ArchiveImageItem {
            get { photos[id: itemID] ?? ArchiveImageItem(id: itemID, imageURL: nil, date: Date()) }
            set { $photos.withLock { $0[id: itemID] = newValue } }
        }
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: item.date)
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        case onTapBackButton
        case onTapDownload
        case onTapFavorite
        case onTapDelete
        
        case delegate(Delegate)
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                
            case .onTapBackButton:
                return .run { _ in await dismiss() }
                
            case .onTapFavorite:
                state.item.isFavorite.toggle()
                return .none
                
            case .onTapDownload:
                print("다운로드: \(state.item.id)")
                return .send(.delegate(.showToast(NekiToastItem("사진을 갤러리에 다운로드했어요", style: .success))))
                
            case .onTapDelete:
                state.$photos.withLock { _ = $0.remove(id: state.itemID) }
                return .run { send in
                    await send(.delegate(.showToast(NekiToastItem("사진을 삭제했어요", style: .success))))
                    await dismiss()
                }
                
            default:
                return .none
            }
        }
    }
    
}
