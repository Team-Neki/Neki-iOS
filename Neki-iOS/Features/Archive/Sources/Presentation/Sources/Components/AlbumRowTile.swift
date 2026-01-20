//
//  AlbumRowTile.swift
//  Neki-iOS
//
//  Created by OneTen on 1/20/26.
//

import SwiftUI
import Kingfisher

struct AlbumRowTile: View {
    let album: AlbumItem
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            KFImage(album.coverImageURL)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .overlay(favoriteHeartOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .nekiFont(.body16SemiBold)
                    .foregroundColor(.gray900)
                
                Text("\(album.count)장")
                    .nekiFont(.caption12Medium)
                    .foregroundColor(.gray500)
            }
            
            Spacer()
        }
    }
}

private extension AlbumRowTile {
    @ViewBuilder
    var favoriteHeartOverlay: some View {
        if album.isFavorite {
            ZStack {
                Color.primary400.opacity(0.5)
                
                Image(systemName: "heart.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 24))
                    .shadow(color: .black.opacity(0.2), radius: 2)
            }
        }
    }
}
