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
                            .foregroundStyle(item.isSelected ? .orange : .white) // 색상 수정 필요 (.primary400 등)
                            .background(
                                Circle()
                                    .fill(item.isSelected ? .white : .black.opacity(0.2)) // 배경 추가로 시인성 확보
                                    .frame(width: 20, height: 20)
                            )
                            .padding(10)
                    }
                }
            // ✨ 선택된 항목 테두리 강조
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.isSelected ? .orange : .clear, lineWidth: 3) // 색상 수정 필요
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .clipped()
    }
}
