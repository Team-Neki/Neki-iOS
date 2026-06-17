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
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            NaverMapView(store: store.scope(state: \.root, action: \.root))
                .navigationBarBackButtonHidden(true)
        } destination: { store in
            switch store.case {
            case .brandReorder(let store):
                PhotoBoothBrandReorderView(store: store)
                    .toolbar(.hidden, for: .tabBar)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
