//
//  ArchiveCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import Foundation
import ComposableArchitecture

@Reducer
struct ArchiveCoordinator {
    
    @ObservableState
    struct State {
        var root = ArchiveFeature.State()
        var path = StackState<Path.State>()
    }
    
    enum Action {
        case root(ArchiveFeature.Action)
        case path(StackActionOf<Path>)
        case delegate(Delegate)
        
        // 상위 코디네이터(MainTab)로 보낼 신호
        enum Delegate {
            case showToast(NekiToastItem)
        }
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) {
            ArchiveFeature()
        }
        
        Reduce { state, action in
            /// 화면전환과 관련된 액션 case만 사용하고 나머지는 default를 이용해 무시
            switch action {
                // root action
            case let .root(.imageTapped(item)):
                state.path.append(.detail(
                    ArchivePhotoDetailFeature.State(photos: state.root.$photos, itemID: item.id)
                ))
                return .none
                
            case .root(.onTapAllPhotos):
                state.path.append(.allPhotos(
                    ArchiveAllPhotosFeature.State(photos: state.root.$photos)
                ))
                return .none
                
            case .root(.onTapAllAlbums):
                state.path.append(.allAlbums(
                    ArchiveAllAlbumsFeature.State(albums: state.root.$albums)
                ))
                return .none
                
                
                // path action
            case let .path(.element(id: id, action: .allPhotos(.imageTapped(item)))):
                guard case let .allPhotos(allPhotosState) = state.path[id: id] else { return .none }
                
                if !allPhotosState.isSelectionMode {
                    state.path.append(.detail(
                        ArchivePhotoDetailFeature.State(photos: state.root.$photos, itemID: item.id)
                    ))
                }
                return .none
                
                
                // toast action
            case let .root(.delegate(.showToast(item))):
                return .send(.delegate(.showToast(item)))
                
            case let .path(.element(id: _, action: .allPhotos(.delegate(.showToast(item))))):
                return .send(.delegate(.showToast(item)))
                
            case let .path(.element(id: _, action: .detail(.delegate(.showToast(item))))):
                return .send(.delegate(.showToast(item)))
                
            case let .path(.element(id: _, action: .allAlbums(.delegate(.showToast(item))))):
                return .send(.delegate(.showToast(item)))
                
            default:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension ArchiveCoordinator {
    @Reducer
    enum Path {
        case detail(ArchivePhotoDetailFeature)
        case allPhotos(ArchiveAllPhotosFeature)
        case allAlbums(ArchiveAllAlbumsFeature)
    }
}
