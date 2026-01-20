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
                // 아카이브 피드에서 이미지 클릭해서 상세 보기
            case let .root(.imageTapped(item)):
                state.path.append(.detail(ArchivePhotoDetailFeature.State(item: item)))
                return .none
                
            case let .root(.delegate(.showToast(item))):
                return .send(.delegate(.showToast(item)))
                
            case let .path(.element(id: _, action: .allPhotos(.delegate(.showToast(item))))):
                return .send(.delegate(.showToast(item)))
                
            case let .path(.element(id: _, action: .detail(.delegate(.showToast(item))))):
                return .send(.delegate(.showToast(item)))
                
            case .root(.onTapAllPhotos):
                // 루트의 사진 데이터를 전달하며 이동
                state.path.append(.allPhotos(
                    ArchiveAllPhotosFeature.State(photos: state.root.photos)
                ))
                return .none
                
            case let .path(.element(id: id, action: .allPhotos(.imageTapped(item)))):
                guard case let .allPhotos(allPhotosState) = state.path[id: id] else { return .none }

                if !allPhotosState.isSelectionMode {
                    state.path.append(.detail(ArchivePhotoDetailFeature.State(item: item)))
                }
                
                return .none
                
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
    }
}
