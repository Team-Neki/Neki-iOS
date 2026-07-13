//
//  FeedImageView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import Kingfisher
import os

struct FeedImageView: View {
    
    @Environment(\.displayScale) private var displayScale
    @Environment(\.nekiImageMaximumDisplayHeight) private var maximumDisplayHeight
    @State private var cardWidth: CGFloat = 200

    //MARK: - Properties
    
    let item: Pose
    let onTapBookmark: (() -> Void)?

    private var imageAspectRatio: CGFloat? {
        guard let width = item.width,
              let height = item.height,
              width > 0,
              height > 0
        else { return nil }

        return CGFloat(width) / CGFloat(height)
    }

    private var imageProcessor: DownsamplingImageProcessor {
        NekiImageDownsampling.processor(
            displayWidth: cardWidth,
            displayScale: displayScale,
            maximumDisplayHeight: maximumDisplayHeight,
            originalWidth: item.width,
            aspectRatio: imageAspectRatio,
            fallbackAspectRatio: 0.75
        )
    }
    
    private static let gradientColor = LinearGradient(
        colors: [
            .black.opacity(0),
            .black
        ],
        startPoint: UnitPoint(x: 0.54, y: 0.42),
        endPoint: UnitPoint(x: 0.54, y: 0.05)
    )
    
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
        }
        .overlay { Color.black.opacity(0.04) }
        .overlay { Self.gradientColor.opacity(0.2) }
        .overlay(alignment: .topTrailing) {
            Button {
                onTapBookmark?()
            } label: {
                Image(item.isScrapped ? .iconBookmark20WhiteFill : .iconBookmark20White)
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .clipped()
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
            guard width > .zero, abs(cardWidth - width) > 1 else { return }
            cardWidth = width
        }
    }
}
