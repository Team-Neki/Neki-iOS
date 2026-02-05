//
//  MarkerImageRenderer.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/5/26.
//

import UIKit
import CoreGraphics

/// 마커 오버레이 상수값 네임스페이스
fileprivate enum MarkerLayout {
    static let normalImageSize: CGFloat = 36.0
    static let selectedImageSize: CGFloat = 48.0
    static let normalPadding: CGFloat = 4.0
    static let selectedPadding: CGFloat = 6.0
    static let normalRadius: CGFloat = 12.0
    static let selectedRadius: CGFloat = 16.0
    static let triangleWidth: CGFloat = 12.0
    static let triangleHeight: CGFloat = 10.0
    static let shadowRadius: CGFloat = 2.5
    static let shadowOffset = CGSize(width: 0, height: 1)
    static let shadowColor = UIColor.black.withAlphaComponent(0.4).cgColor
}

struct MarkerImageRenderer {
    static func render(brandImage: UIImage?, isSelected: Bool) -> UIImage {
        let imageSize = isSelected ? MarkerLayout.selectedImageSize : MarkerLayout.normalImageSize
        let padding = isSelected ? MarkerLayout.selectedPadding : MarkerLayout.normalPadding
        let bodySize = imageSize + (padding * 2)
        
        let canvasSize = CGSize(
            width: bodySize + (MarkerLayout.shadowRadius * 2),
            height: bodySize + MarkerLayout.triangleHeight + (MarkerLayout.shadowRadius * 2)
        )
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        
        return renderer.image { context in
            let context = context.cgContext
            let offsetX = (canvasSize.width - bodySize) / 2
            let offsetY = MarkerLayout.shadowRadius
            let bodyRect = CGRect(x: offsetX, y: offsetY, width: bodySize, height: bodySize)
            
            // 1. 그림자
            context.setShadow(offset: MarkerLayout.shadowOffset, blur: MarkerLayout.shadowRadius, color: MarkerLayout.shadowColor)
            
            // 2. 배경 (몸통 + 꼬리)
            let cornerRadius = isSelected ? MarkerLayout.selectedRadius : MarkerLayout.normalRadius
            let path = UIBezierPath(roundedRect: bodyRect, cornerRadius: cornerRadius)
            
            let trianglePath = UIBezierPath()
            let triangleStart = CGPoint(x: canvasSize.width / 2 - MarkerLayout.triangleWidth / 2, y: bodyRect.maxY)
            trianglePath.move(to: triangleStart)
            trianglePath.addLine(to: CGPoint(x: canvasSize.width / 2, y: bodyRect.maxY + MarkerLayout.triangleHeight))
            trianglePath.addLine(to: CGPoint(x: canvasSize.width / 2 + MarkerLayout.triangleWidth / 2, y: bodyRect.maxY))
            trianglePath.close()
            path.append(trianglePath)
            
            if isSelected {
                context.saveGState()
                path.addClip()
                // 그라디언트 (예시: 다크 그레이 -> 블랙)
                let colors = [UIColor.darkGray.cgColor, UIColor.black.cgColor]
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: bodyRect.minY), end: CGPoint(x: 0, y: bodyRect.maxY), options: [])
                context.restoreGState()
            } else {
                UIColor.white.setFill()
                path.fill()
            }
            
            // 3. 브랜드 이미지
            context.setShadow(offset: .zero, blur: 0, color: nil)
            let innerImageRect = bodyRect.insetBy(dx: padding, dy: padding)
            let imagePath = UIBezierPath(roundedRect: innerImageRect, cornerRadius: isSelected ? 8.0 : 6.0)
            
            context.saveGState()
            imagePath.addClip()
            
            if let image = brandImage {
                image.draw(in: innerImageRect)
            } else {
                UIColor.systemGray5.setFill()
                UIRectFill(innerImageRect)
            }
            context.restoreGState()
        }
    }
}
