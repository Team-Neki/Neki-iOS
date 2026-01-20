//
//  ArchiveAllAlbumsView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/20/26.
//

import SwiftUI
import ComposableArchitecture

struct ArchiveAllAlbumsView: View {
    @Bindable var store: StoreOf<ArchiveAllAlbumsFeature>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(store.albums) { album in
                        AlbumRowTile(album: album)
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.top, 8)
                .padding(.horizontal, 20)
            }
        }
        .nekiToolbar(left: .back(action: {}),
                     center: .text("모든 앨범"),
                     right: .both([.text("생성", action: {}), .icon(.iconEllipsis, action: {})]))
    }
}
