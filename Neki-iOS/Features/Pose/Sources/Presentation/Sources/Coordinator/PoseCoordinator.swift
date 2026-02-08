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
        // Child
        case root(PoseFeature.Action)
        case path(StackActionOf<Path>)
        
        // Navigation
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
            switch action {
                
                // MARK: - Navigation Triggers from Root
            case let .root(.delegate(.didTapImage(pose))):
                state.path.append(.detail(PoseDetailFeature.State(poses: state.root.filteredPoses, selectedID: pose.id)))
                return .none
                
            case let .root(.delegate(.didTapStartRandomPose(option))):
                state.path.append(.randomPose(RandomPoseCarouselFeature.State(peopleCount: option)))
                return .none
                
                // MARK: - Data Synchronization (Coordinator's Main Job)
            case let .path(.element(_, action: .detail(.delegate(.poseUpdated(pose))))):
                return .send(.root(.updatePoseInList(pose)))
                
            case let .path(.element(_, action: .randomPose(.delegate(.poseUpdated(pose))))):
                return .send(.root(.updatePoseInList(pose)))
                
                // MARK: - Navigation from Random Pose
            case let .path(.element(_, action: .randomPose(.delegate(.routeToDetail(pose))))):
                return .send(.routeToDetail(pose))
                
            case let .routeToDetail(pose):
                state.path.append(.detail(PoseDetailFeature.State(
                    poses: state.root.filteredPoses,
                    selectedID: pose.id
                )))
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
        case randomPose(RandomPoseCarouselFeature)
    }
}
