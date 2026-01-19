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
                .aspectRatio(contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if item.isScrapped {
                        Image(.iconHeart20)
                            .padding(10)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isSelectionMode {
                        Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(item.isSelected ? .primary400 : .white)
                            .background(
                                Circle()
                                    .fill(item.isSelected ? .white : .black.opacity(0.2))
                                    .frame(width: 24, height: 24)
                            )
                            .padding(12)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(item.isSelected ? .primary400 : .clear, lineWidth: 2)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .clipped()
    }
}
