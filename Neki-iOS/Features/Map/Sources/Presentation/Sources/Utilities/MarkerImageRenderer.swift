
//  MarkerImageRenderer.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/5/26.
//

import SwiftUI
import CoreGraphics

private enum MarkerLayout {
    static let normalBgRadius: CGFloat = 16.2
    static let normalImageSize: CGFloat = 50.0
    static let normalImageRadius: CGFloat = 15.0
    static let normalPadding: CGFloat = 2.0
    
    static let selectedBgRadius: CGFloat = 21.6
    static let selectedImageSize: CGFloat = 60.0
    static let selectedImageRadius: CGFloat = 18.0
    static let selectedPadding: CGFloat = 6.0
    
    static let normalFavoriteBadgeSize: CGFloat = 30
    static let selectedFavoriteBadgeSize: CGFloat = 36
    static let normalFavoriteBadgeOffset = CGSize(width: -4, height: 4)
    static let selectedFavoriteBadgeOffset = CGSize.zero
    
    static let tailWidth: CGFloat = 12.0
    static let tailHeight: CGFloat = 10.0
    
    static let shadowRadius: CGFloat = 2.5
    static let shadowOffset = CGSize(width: 0, height: 1)
    static let shadowColor = UIColor.black.withAlphaComponent(0.4).cgColor
    
    static let solidColor: UIColor = .white
    static let gradientColors: [UIColor] = [.darkGray, .black]
}

enum MarkerImageRenderer {
    static func render(
        brandImage: UIImage?,
        isSelected: Bool,
        isFavorite: Bool,
        displayScale: CGFloat
    ) -> UIImage {
        let displayScale = displayScale.isFinite && displayScale > .zero ? displayScale : 1
        let imageSize = isSelected ? MarkerLayout.selectedImageSize : MarkerLayout.normalImageSize
        let padding = isSelected ? MarkerLayout.selectedPadding : MarkerLayout.normalPadding
        let imageRadius = isSelected ? MarkerLayout.selectedImageRadius : MarkerLayout.normalImageRadius
        let bgRadius = isSelected ? MarkerLayout.selectedBgRadius : MarkerLayout.normalBgRadius
        let favoriteBadgeSize = isSelected ? MarkerLayout.selectedFavoriteBadgeSize : MarkerLayout.normalFavoriteBadgeSize
        let favoriteBadgeOffset = isSelected ? MarkerLayout.selectedFavoriteBadgeOffset : MarkerLayout.normalFavoriteBadgeOffset
        let tailSize = CGSize(width: MarkerLayout.tailWidth, height: MarkerLayout.tailHeight)
        let bodySize = imageSize + (padding * 2)

        let badgeOverflow = isFavorite ? favoriteBadgeSize / 2 : .zero
        let totalWidth = bodySize + badgeOverflow
        let totalHeight = bodySize + tailSize.height - 1
        
        let shadowMargin = MarkerLayout.shadowRadius * 4
        let canvasSize = CGSize(
            width: totalWidth + shadowMargin * 2,
            height: totalHeight + badgeOverflow + shadowMargin * 2
        )
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = displayScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            let drawOffsetX = shadowMargin + badgeOverflow / 2
            let drawOffsetY = MarkerLayout.shadowRadius + badgeOverflow
            let bodyRect = pixelAligned(
                CGRect(
                    x: drawOffsetX,
                    y: drawOffsetY,
                    width: bodySize,
                    height: bodySize
                ),
                scale: displayScale
            )
            
            let tailOrigin = pixelAligned(
                CGPoint(
                    x: bodyRect.midX - tailSize.width / 2,
                    y: bodyRect.maxY - 1
                ),
                scale: displayScale
            )
            
            let tailPath = UIBezierPath()
            tailPath.move(to: .zero)
            tailPath.addLine(to: CGPoint(x: tailSize.width, y: 0))
            tailPath.addLine(to: CGPoint(x: tailSize.width / 2, y: tailSize.height))
            tailPath.close()
            
            let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: bgRadius)
            cgContext.saveGState()
            cgContext.setShadow(offset: MarkerLayout.shadowOffset, blur: MarkerLayout.shadowRadius, color: MarkerLayout.shadowColor)
            UIColor.black.setFill()
            bodyPath.fill()
            cgContext.setBlendMode(.clear)
            bodyPath.fill()
            cgContext.restoreGState()
            cgContext.saveGState()
            cgContext.translateBy(x: tailOrigin.x, y: tailOrigin.y)
            cgContext.setShadow(offset: MarkerLayout.shadowOffset, blur: MarkerLayout.shadowRadius, color: MarkerLayout.shadowColor)
            UIColor.black.setFill()
            tailPath.fill()
            cgContext.setBlendMode(.clear)
            tailPath.fill()
            cgContext.restoreGState()
            cgContext.saveGState()
            if isSelected {
                cgContext.addPath(bodyPath.cgPath)
                cgContext.clip()
                let colors = MarkerLayout.gradientColors.map { $0.cgColor } as CFArray
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: nil) {
                    cgContext.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: bodyRect.midX, y: bodyRect.minY),
                        end: CGPoint(x: bodyRect.midX, y: bodyRect.maxY),
                        options: []
                    )
                }
            } else {
                MarkerLayout.solidColor.setFill()
                bodyPath.fill()
            }
            cgContext.restoreGState()
            cgContext.saveGState()
            cgContext.translateBy(x: tailOrigin.x, y: tailOrigin.y)
            let tailFillColor = isSelected ? MarkerLayout.gradientColors[1] : MarkerLayout.solidColor
            tailFillColor.setFill()
            tailPath.fill()
            cgContext.restoreGState()
            let imageRect = pixelAligned(
                CGRect(
                    x: bodyRect.minX + padding,
                    y: bodyRect.minY + padding,
                    width: imageSize,
                    height: imageSize
                ),
                scale: displayScale
            )
            
            let imagePath = UIBezierPath(roundedRect: imageRect, cornerRadius: imageRadius)
            
            cgContext.saveGState()
            cgContext.addPath(imagePath.cgPath)
            cgContext.clip()
            
            if let image = brandImage {
                let sourceSize = orientedPixelSize(of: image)
                let physicalPixel = 1 / displayScale
                let drawRect = aspectFillRect(
                    sourceSize: sourceSize,
                    targetRect: imageRect.insetBy(dx: -physicalPixel, dy: -physicalPixel)
                )
                image.draw(in: drawRect)
            } else {
                UIColor.systemGray5.setFill()
                UIRectFill(imageRect)
            }
            cgContext.restoreGState()

            guard isFavorite else { return }

            let badgeImage = UIImage(resource: .iconFavoriteBooth)
            let badgeRect = CGRect(
                x: imageRect.maxX - favoriteBadgeSize / 2 + favoriteBadgeOffset.width,
                y: imageRect.minY - favoriteBadgeSize / 2 + favoriteBadgeOffset.height,
                width: favoriteBadgeSize,
                height: favoriteBadgeSize
            )
            badgeImage.draw(in: badgeRect)
        }
    }
}

// MARK: - MarkerImageRenderer + Image Geometry

private extension MarkerImageRenderer {
    static func orientedPixelSize(of image: UIImage) -> CGSize {
        guard let cgImage = image.cgImage else {
            return CGSize(
                width: image.size.width * image.scale,
                height: image.size.height * image.scale
            )
        }

        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: cgImage.height, height: cgImage.width)
        default:
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
    }

    static func aspectFillRect(
        sourceSize: CGSize,
        targetRect: CGRect
    ) -> CGRect {
        guard sourceSize.width > .zero, sourceSize.height > .zero else { return targetRect }
        let aspectRatio = max(targetRect.width / sourceSize.width, targetRect.height / sourceSize.height)
        let drawnSize = CGSize(
            width: sourceSize.width * aspectRatio,
            height: sourceSize.height * aspectRatio
        )
        return CGRect(
            x: targetRect.midX - drawnSize.width / 2,
            y: targetRect.midY - drawnSize.height / 2,
            width: drawnSize.width,
            height: drawnSize.height
        )
    }

    static func pixelAligned(_ point: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: (point.x * scale).rounded() / scale,
            y: (point.y * scale).rounded() / scale
        )
    }

    static func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let origin = pixelAligned(rect.origin, scale: scale)
        let maxPoint = pixelAligned(
            CGPoint(x: rect.maxX, y: rect.maxY),
            scale: scale
        )
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: maxPoint.x - origin.x,
            height: maxPoint.y - origin.y
        )
    }
}
