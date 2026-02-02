//
//  PoseCoordinatorView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

struct PoseCoordinatorView: View {
    @Bindable var store: StoreOf<PoseCoordinator>
    
    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            PoseView(store: store.scope(state: \.root, action: \.root))
        } destination: { store in
            switch store.case {
            case .detail(let store):
                PoseDetailView(store: store)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        .fullScreenCover(item: $store.scope(state: \.randomPose, action: \.randomPose)) { store in
            RandomPoseCarouselView(store: store)
        }
    }
}
