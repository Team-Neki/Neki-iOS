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
            case requestJumpToPose(FeedImageItem)
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
                state.path.append(.detail(ArchiveDetailFeature.State(item: item)))
                return .none
                
                // 아카이브 상세에서 더 자세히 보기 클릭
            case let .path(.element(id: _, action: .detail(.didTapDeepLinkButton(item)))):
                state.path.append(.deepDetail(ArchiveDeepDetailFeature.State(item: item)))
                return .none
                
                // [DeepDetail -> Root] 한 번에 이동
            case .path(.element(id: _, action: .deepDetail(.didTapPopToRoot))):
                state.path.removeAll()
                return .none
                
                // 아카이브에서 포즈의 특정 사진 디테일 화면으로 이동 (Feature간 이동)
            case .path(.element(id: _, action: .deepDetail(.didTapJumpToPose))):
                guard case let .deepDetail(deepState) = state.path.last else { return .none }
                return .send(.delegate(.requestJumpToPose(deepState.item.toFeedImageItem())))
                
            default:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
    
    @Reducer
    enum Path {
        case detail(ArchiveDetailFeature)
        case deepDetail(ArchiveDeepDetailFeature)
    }
}
