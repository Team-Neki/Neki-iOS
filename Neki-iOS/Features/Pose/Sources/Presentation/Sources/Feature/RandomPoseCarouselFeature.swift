//
//  RandomPoseCarouselFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation
import ComposableArchitecture
import os

@Reducer
struct RandomPoseCarouselFeature {
    enum SlideDirection { case previous, next, none }
    
    private enum CancelID: Hashable {
        case poseRequest
        case scrap(PoseID)
    }
    
    @ObservableState
    struct State {
        @Shared(.appStorage("RandomPoseTutorial")) var isTutorialPresented: Bool = true
        
        var currentPose: Pose?
        var isLoading: Bool = false
        var activePeopleCount: PeopleCountOption
        var isScrapped: Bool { currentPose?.isScrapped ?? false }
        var isDismissing: Bool = false
        var slideDirection: SlideDirection = .none
        var totalSwipeCount: Int = .zero
        
        init(peopleCount: PeopleCountOption) { activePeopleCount = peopleCount }
    }
    
    enum Action {
        // Lifecycle Actions
        case onAppear
        
        // View Actions
        case closeTutorialOverlay
        case onTapClose
        case tapLeft, tapRight
        case onTapScrap
        case onTapDetail(Pose)
        
        // Internal Actions
        /// 포즈 요청 결과입니다. 좌우로 넘겨 요청한 결과인지 함께 받아, 성공한 넘김만 스와이프 수로 셉니다.
        case poseResponse(Result<Pose, Error>, isSwipe: Bool)
        case scrapResponse(Pose, Result<Void, Error>)
        
        // Delegate Actions
        case delegate(Delegate)
        enum Delegate {
            case poseUpdated(Pose)
            case routeToDetail(Pose)
        }
    }
    
    @Dependency(\.poseClient) private var poseClient
    @Dependency(\.analyticsClient) private var analytics
    @Dependency(\.dismiss) private var dismiss
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
                // MARK: - Lifecycle & View Actions
            case .onAppear:
                guard state.currentPose == nil else { return .none }
                state.isLoading = true
                return .run { [count = state.activePeopleCount] send in
                    await send(.poseResponse(Result { try await poseClient.initializeRandomPose(peopleCount: count) }, isSwipe: false))
                }
                
            case .closeTutorialOverlay:
                state.$isTutorialPresented.withLock { $0 = false }
                return .none
                
            case .onTapClose:
                // 랜덤 포즈 종료 기록과 미리 불러온 랜덤 포즈 비우기는 닫기 버튼과 뒤로 스와이프 모두 이 화면이 스택에서 빠질 때 포즈 코디네이터가 맡습니다.
                return .run { _ in await dismiss() }
                
            case .tapLeft:
                state.slideDirection = .previous
                state.isLoading = true
                return .run { send in
                    await send(.poseResponse(Result { try await poseClient.startRandomPoseSuggestion(direction: .left) }, isSwipe: true))
                }
                .cancellable(id: CancelID.poseRequest)
                
            case .tapRight:
                state.slideDirection = .next
                state.isLoading = true
                return .run { send in
                    await send(.poseResponse(Result { try await poseClient.startRandomPoseSuggestion(direction: .right) }, isSwipe: true))
                }
                .cancellable(id: CancelID.poseRequest)
                
                // MARK: - Scrap Logic (Optimistic)
            case .onTapScrap:
                guard var pose = state.currentPose else { return .none }
                let originalPose = pose
                pose.isScrapped.toggle()
                state.currentPose = pose
                
                let scrapEffect: Effect<Action> = .run { [originalPose, updatedPose = pose] send in
                    await send(.delegate(.poseUpdated(updatedPose)))
                    await send(.scrapResponse(originalPose, Result { try await poseClient.scrapPose(poseID: originalPose.id) }))
                }
                .cancellable(id: CancelID.scrap(pose.id), cancelInFlight: true)
                let trackingEffect: Effect<Action> = .run { _ in await analytics.logEvent(PoseAnalyticsEvent.poseBookmark) }
                
                return .merge(scrapEffect, trackingEffect)
                
                // MARK: - Internal Actions
            case let .poseResponse(.success(pose), isSwipe):
                state.isLoading = false
                state.currentPose = pose
                if isSwipe { state.totalSwipeCount += 1 }
                return .none
                
            case let .poseResponse(.failure(error), _):
                state.isLoading = false
                Logger.presentation.error("Random Pose Fetching Failed: \(error)")
                return .none
                
            case .scrapResponse(_, .success):
                return .none
                
            case let .scrapResponse(originalPose, .failure(error)):
                if error is CancellationError { return .none }
                Logger.presentation.error("Error occured while scrapping pose: ID-\(originalPose.id) / Error: \(error)")
                
                if state.currentPose?.id == originalPose.id {
                    state.currentPose = originalPose
                    return .send(.delegate(.poseUpdated(originalPose)))
                }
                
                return .none
                
                // MARK: - Navigation
            case let .onTapDetail(pose):
                return .run { send in
                    await send(.delegate(.routeToDetail(pose)))
                }
                
            case .delegate:
                return .none
            }
        }
    }
}
