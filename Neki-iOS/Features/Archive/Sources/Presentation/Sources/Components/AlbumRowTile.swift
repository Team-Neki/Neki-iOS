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
    let isSelectMode: Bool
    let isDeleteMode: Bool
    let isSelected: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            KFImage(album.coverImageURL)
                .placeholder({
                    Image(.temporaryBranding)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipped()
                })
                .resizable()
                .cancelOnDisappear(true)
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
            
            if isSelectMode && !album.isFavorite || isDeleteMode && !album.isFavorite {
                selectionIndicator
            }
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
                    .frame(width: 20, height: 20)
            }
        }
    }
    
    @ViewBuilder
    var selectionIndicator: some View {
        let shouldShowCheckbox: Bool = {
            if isSelectMode && !album.isFavorite { return true }
            if isDeleteMode && !album.isFavorite { return true }
            return false
        }()
        
        if shouldShowCheckbox {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? .primary400 : .white)
                .background(
                    Circle()
                        .stroke(isSelected ? .primary400 : .gray75, lineWidth: 2)
                        .frame(width: 24, height: 24)
                )
        }
    }
}
