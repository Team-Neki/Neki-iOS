//
//  MapCoordinatorView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/24/26.
//

import SwiftUI
import ComposableArchitecture

struct MapCoordinatorView: View {
    @Bindable var store: StoreOf<MapCoordinator>
    
    var body: some View {
        NaverMapView(store: store.scope(state: \.root, action: \.root))
    }
}
