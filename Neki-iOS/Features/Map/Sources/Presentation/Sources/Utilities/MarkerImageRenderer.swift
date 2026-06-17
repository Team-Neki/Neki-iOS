
//  MarkerImageRenderer.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/5/26.
//

import SwiftUI
import CoreGraphics

fileprivate enum MarkerLayout {
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

struct MarkerImageRenderer {
    static func render(
        brandImage: UIImage?,
        isSelected: Bool,
        isFavorite: Bool
    ) -> UIImage {
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
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            let drawOffsetX = shadowMargin + badgeOverflow / 2
            let drawOffsetY = MarkerLayout.shadowRadius + badgeOverflow
            let bodyRect = CGRect(
                x: drawOffsetX,
                y: drawOffsetY,
                width: bodySize,
                height: bodySize
            )
            
            let tailOrigin = CGPoint(
                x: drawOffsetX + bodySize / 2 - tailSize.width / 2,
                y: drawOffsetY + bodySize - 1
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
            let imageRect = CGRect(
                x: bodyRect.minX + padding,
                y: bodyRect.minY + padding,
                width: imageSize,
                height: imageSize
            )
            
            let imagePath = UIBezierPath(roundedRect: imageRect, cornerRadius: imageRadius)
            
            cgContext.saveGState()
            cgContext.addPath(imagePath.cgPath)
            cgContext.clip()
            
            if let image = brandImage {
                let aspectRatio = max(imageRect.width / image.size.width, imageRect.height / image.size.height)
                let drawnSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)
                let offsetX = (drawnSize.width - imageRect.width) / 2
                let offsetY = (drawnSize.height - imageRect.height) / 2
                let drawRect = CGRect(x: imageRect.minX - offsetX, y: imageRect.minY - offsetY, width: drawnSize.width, height: drawnSize.height)
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
