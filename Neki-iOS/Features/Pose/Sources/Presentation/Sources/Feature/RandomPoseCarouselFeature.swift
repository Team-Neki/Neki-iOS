//
//  RandomPoseCarouselFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation
import ComposableArchitecture

@Reducer
struct RandomPoseCarouselFeature {
    @ObservableState
    struct State {
        @Shared(.appStorage("RandomPoseTutorial")) var isTutorialPresented: Bool = true
        
        var poseImages: [String] = ["pose1", "pose2", "pose3", "pose4"]
        var currentIndex: Int = .zero
    }
    
    enum Action {
        // View Actions
        case closeTutorialOverlay
        case tapLeft, tapRight
    }
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .closeTutorialOverlay:
                state.$isTutorialPresented.withLock { $0 = false }
                return .none
                
            case .tapLeft:
                let previousIndex = state.currentIndex - 1
                state.currentIndex = previousIndex < .zero ? state.poseImages.count - 1 : previousIndex
                return .none
                
            case .tapRight:
                let nextIndex = state.currentIndex + 1
                state.currentIndex = nextIndex >= state.poseImages.count ? .zero : nextIndex
                return .none
            }
        }
    }
}
