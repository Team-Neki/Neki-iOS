//
//  NekiImageDownsampling.swift
//  Neki-iOS
import SwiftUI
import Kingfisher

enum NekiImageDownsampling {
    static func processor(
        displayWidth: CGFloat,
        displayScale: CGFloat,
        maximumDisplayHeight: CGFloat,
        originalWidth: Int?,
        aspectRatio: CGFloat?,
        fallbackAspectRatio: CGFloat
    ) -> DownsamplingImageProcessor {
        let targetWidth = targetPixelWidth(
            displayWidth: displayWidth,
            displayScale: displayScale,
            originalWidth: originalWidth
        )
        let targetHeight = min(
            targetWidth / validAspectRatio(aspectRatio, fallback: fallbackAspectRatio),
            maximumPixelHeight(displayHeight: maximumDisplayHeight, displayScale: displayScale)
        )

        return DownsamplingImageProcessor(size: CGSize(width: targetWidth, height: targetHeight))
    }

    private static func targetPixelWidth(
        displayWidth: CGFloat,
        displayScale: CGFloat,
        originalWidth: Int?
    ) -> CGFloat {
        let fallbackWidth = max(displayWidth, 1) * displayScale
        guard let originalWidth, originalWidth > .zero else { return fallbackWidth }
        return min(fallbackWidth, CGFloat(originalWidth))
    }

    private static func maximumPixelHeight(displayHeight: CGFloat, displayScale: CGFloat) -> CGFloat {
        guard displayHeight.isFinite, displayHeight > .zero else { return .greatestFiniteMagnitude }
        return displayHeight * displayScale
    }

    private static func validAspectRatio(_ aspectRatio: CGFloat?, fallback: CGFloat) -> CGFloat {
        guard let aspectRatio, aspectRatio > .zero else { return max(fallback, .leastNonzeroMagnitude) }
        return aspectRatio
    }
}
