//
//  ArchiveImageCard.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import Kingfisher
import os

struct ArchiveImageCard: View {
    
    //MARK: - Properties
    
    let item: ArchiveImageItem
    let isSelectionMode: Bool
    let isSelected: Bool
    
    let gradientColor: LinearGradient = LinearGradient(
        colors: [
            .black.opacity(0),
            .black
        ],
        startPoint: UnitPoint(x: 0.54, y: 0.42),
        endPoint: UnitPoint(x: 0.54, y: 0.05)
    )
    
    //MARK: - Init

    init(
        item: ArchiveImageItem,
        isSelectionMode: Bool = false,
        isSelected: Bool = false
    ) {
        self.item = item
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
    }
    
    //MARK: - Main Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KFImage(item.imageURL)
                .resizable()
                .fade(duration: 0.25)
                .retry(maxCount: 3, interval: .seconds(5))
                .onFailure { error in
                    Logger.presentation.error("이미지 로드 실패: \(error)")
                    Logger.presentation.error("실패한 이미지 id: \(item.id)")
                }
                .cancelOnDisappear(true)
                .aspectRatio(contentMode: .fit)
                .overlay(content: {
                    Color.black.opacity(0.04)
                })
                .overlay(content: {
                    gradientColor.opacity(0.2)
                })
                .overlay(alignment: .topTrailing) {
                    if item.isFavorite {
                        Image(.iconHeart20)
                            .padding(10)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isSelectionMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(isSelected ? .primary400 : .white)
                            .background(
                                Circle()
                                    .fill(isSelected ? .white : .black.opacity(0.2))
                                    .frame(width: 24, height: 24)
                            )
                            .padding(12)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? .primary400 : .clear, lineWidth: 2)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .clipped()
    }
}
