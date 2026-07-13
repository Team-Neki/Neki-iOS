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
    @Environment(\.displayScale) private var displayScale
    @State private var cardWidth: CGFloat = 200
    
    let item: PhotoEntity
    let isSelectionMode: Bool
    let isSelected: Bool
    let maximumDisplayHeight: CGFloat
    let onTapFavorite: (() -> Void)
    
    private static let gradientColor = LinearGradient(
        colors: [
            .black.opacity(0),
            .black
        ],
        startPoint: UnitPoint(x: 0.54, y: 0.42),
        endPoint: UnitPoint(x: 0.54, y: 0.05)
    )
    
    private var imageAspectRatio: CGFloat? {
        if let width = item.width, let height = item.height, width > 0, height > 0 {
            return CGFloat(width) / CGFloat(height)
        }
        return nil
    }

    private var imageProcessor: DownsamplingImageProcessor {
        NekiImageDownsampling.processor(
            displayWidth: cardWidth,
            displayScale: displayScale,
            maximumDisplayHeight: maximumDisplayHeight,
            originalWidth: item.width,
            aspectRatio: imageAspectRatio,
            fallbackAspectRatio: 0.5
        )
    }
    
    //MARK: - Init
    
    init(
        item: PhotoEntity,
        isSelectionMode: Bool = false,
        isSelected: Bool = false,
        maximumDisplayHeight: CGFloat = .infinity,
        onTapFavorite: @escaping () -> Void
    ) {
        self.item = item
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self.maximumDisplayHeight = maximumDisplayHeight
        self.onTapFavorite = onTapFavorite
    }
    
    //MARK: - Main Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KFImage(item.imageURL)
                .setProcessor(imageProcessor)
                .cacheOriginalImage()
                .resizable()
                .fade(duration: 0.25)
                .retry(maxCount: 3, interval: .seconds(5))
                .onFailure { error in
                    Logger.presentation.error("이미지 로드 실패: \(error)")
                    Logger.presentation.error("실패한 이미지 id: \(item.id)")
                }
                .cancelOnDisappear(true)
                .aspectRatio(imageAspectRatio, contentMode: .fit)
                .overlay(content: {
                    Color.black.opacity(0.04)
                })
                .overlay(content: {
                    Self.gradientColor.opacity(0.2)
                })
                .overlay(alignment: .topTrailing) {
                    Button {
                        onTapFavorite()
                    } label: {
                        Image(item.isFavorite ? .iconHeart20WhiteFill : .iconHeart20White)
                    }
                    .padding(10)
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
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
            guard width > .zero, abs(cardWidth - width) > 1 else { return }
            cardWidth = width
        }
    }
}
