//
//  ArchiveCoordinatorView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/14/26.
//

import SwiftUI
import ComposableArchitecture

struct ArchiveCoordinatorView: View {
    @Bindable var store: StoreOf<ArchiveCoordinator>
    
    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ArchiveView(store: store.scope(state: \.root, action: \.root))
                .navigationBarBackButtonHidden()
        } destination: { store in
            switch store.case {
            case .detail(let store):
                ArchivePhotoDetailView(store: store)
                    .navigationBarBackButtonHidden()
                
            case .allPhotos(let store):
                ArchiveAllPhotosView(store: store)
                    .navigationBarBackButtonHidden()
                
            case .allAlbums(let store):
                ArchiveAllAlbumsView(store: store)
                    .navigationBarBackButtonHidden()
            }
        }
    }
}
