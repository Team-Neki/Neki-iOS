//
//  PoseCoordinator.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import Foundation
import ComposableArchitecture

@Reducer
struct PoseCoordinator {
    
    @ObservableState
    struct State {
        var root = PoseFeature.State()
        var path = StackState<Path.State>()
    }
    
    enum Action {
        case root(PoseFeature.Action)
        case path(StackActionOf<Path>)
        
        case routeToDetail(FeedImageItem)
        
        case delegate(Delegate)
        enum Delegate {
            case logout
        }
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) {
            PoseFeature()
        }
        
        Reduce { state, action in
            /// 화면전환과 관련된 액션 case만 사용하고 나머지는 default를 이용해 무시
            switch action {
                // 포즈 피드에서 이미지 클릭해서 상세 보기
            case let .root(.imageTapped(item)):
                state.path.append(.detail(PoseDetailFeature.State(
                    items: state.root.items, // 전체 리스트 전달
                    selectedID: item.id      // 클릭한 아이템의 ID 전달
                )))
                return .none
                
            case let .routeToDetail(item):
                // 기존 스택을 비우고 싶다면: state.path.removeAll()
                // 포즈 외부에서 이미지 디테일 뷰로 이동 (Feature간 전환)
                state.path.append(.detail(PoseDetailFeature.State(
                    items: state.root.items, // 전체 리스트 전달
                    selectedID: item.id      // 클릭한 아이템의 ID 전달
                )))
                return .none
                
            case .path(.element(id: _, action: .detail(.didTapBackButton))):
                state.path.removeLast()
                return .none
                
                
            default:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension PoseCoordinator {
    @Reducer
    enum Path {
        case detail(PoseDetailFeature)
    }
}
