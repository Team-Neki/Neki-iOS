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
            case requestQRScan
            case requestNotificationList
        }
    }
    
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.poseClient) private var poseClient
    
    var body: some ReducerOf<Self> {
        Scope(state: \.root, action: \.root) {
            PoseFeature()
        }
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                
                // MARK: - Navigation Triggers from Root
            case let .root(.delegate(.didTapImage(pose))):
                state.path.append(.detail(PoseDetailFeature.State(
                    poses: IdentifiedArray(uniqueElements: state.root.visiblePoses),
                    selectedID: pose.id
                )))
                return .none
                
            case let .root(.delegate(.didTapStartRandomPose(option))):
                // 랜덤 포즈 시작은 랜덤 포즈 화면을 띄울 때 한 번 기록합니다. 첫 포즈를 불러오기 전에 보내므로 불러오기에 실패해도 남습니다.
                state.path.append(.randomPose(RandomPoseCarouselFeature.State(peopleCount: option)))
                return .run { _ in await analytics.logEvent(PoseAnalyticsEvent.randomPoseSuggestionStart) }
                
            case .root(.delegate(.qrScanButtonTapped)):
                return .send(.delegate(.requestQRScan))

            case .root(.delegate(.requestNotificationList)):
                return .send(.delegate(.requestNotificationList))
                
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
                    poses: IdentifiedArray(uniqueElements: state.root.visiblePoses),
                    selectedPose: pose
                )))
                return .none
                
                // MARK: - Random Pose Session
            case let .path(.popFrom(id)):
                // 닫기 버튼이나 뒤로 스와이프로 랜덤 포즈 화면이 스택에서 빠지면 랜덤 포즈를 끝낸 것으로 기록하고, 미리 불러온 랜덤 포즈를 비웁니다.
                // 화면이 빠지기 전에 불리므로 넘긴 수를 읽을 수 있고, 위에 쌓인 화면과 함께 빠져도 랜덤 포즈마다 한 번씩 남깁니다.
                guard let index = state.path.ids.firstIndex(of: id) else { return .none }
                let totalSwipeCounts = state.path.ids[index...].compactMap { state.path[id: $0]?.randomPose?.totalSwipeCount }
                guard totalSwipeCounts.isEmpty == false else { return .none }
                return .run { _ in
                    await poseClient.stopRandomPoseSuggestion()
                    for totalSwipeCount in totalSwipeCounts {
                        await analytics.logEvent(PoseAnalyticsEvent.randomPoseSuggestionEnd(totalSwipeCount: totalSwipeCount))
                    }
                }
                
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
