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
        @Presents var randomPose: RandomPoseCarouselFeature.State?
    }
    
    enum Action {
        case root(PoseFeature.Action)
        case path(StackActionOf<Path>)
        case randomPose(PresentationAction<RandomPoseCarouselFeature.Action>)
        
        case routeToDetail(Pose)
        
        case delegate(Delegate)
        enum Delegate {
            case logout
        }
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) {
            PoseFeature()
        }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            /// 화면전환과 관련된 액션 case만 사용하고 나머지는 default를 이용해 무시
            switch action {
                // 포즈 피드에서 이미지 클릭해서 상세 보기
            case let .root(.imageTapped(item)):
                state.path.append(.detail(PoseDetailFeature.State(poses: state.root.filteredPoses , selectedID: item.id)))
                return .none
                
            case .root(.onTapStartRandomPoseCarousel):
                state.randomPose = RandomPoseCarouselFeature.State(peopleCount: state.root.selectedRandomPoseCountSelectionOption)
                return .none
                
            case let .path(.element(id: _, action: .detail(.poseUpdated(pose)))):
                if state.root.poses.contains(pose) { state.root.poses[id: pose.id] = pose }
                return .none
                
            case let .randomPose(.presented(.poseUpdated(pose))):
                if state.root.poses.contains(pose) { state.root.poses[id: pose.id] = pose }
                return .none
                
            case let .routeToDetail(pose):
                // 기존 스택을 비우고 싶다면: state.path.removeAll()
                // 포즈 외부에서 이미지 디테일 뷰로 이동 (Feature간 전환)
                state.path.append(.detail(PoseDetailFeature.State(
                    poses: state.root.poses, // 전체 리스트 전달
                    selectedID: pose.id      // 클릭한 아이템의 ID 전달
                )))
                return .none
                
            case let .randomPose(.presented(.onTapDetail(pose))):
                state.randomPose = nil
                return .send(.routeToDetail(pose))
                
            default:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$randomPose, action: \.randomPose) { RandomPoseCarouselFeature() }
    }
}

extension PoseCoordinator {
    @Reducer
    enum Path {
        case detail(PoseDetailFeature)
    }
}
