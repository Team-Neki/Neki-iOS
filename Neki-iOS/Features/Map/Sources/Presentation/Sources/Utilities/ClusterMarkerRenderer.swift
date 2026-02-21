//
//  ClusterMarkerRenderer.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/20/26.
//

import SwiftUI
import CoreGraphics

fileprivate enum ClusteringLayout {
    static let imageSize: CGFloat = 50.0
    static let padding: CGFloat = 2.0
    
    static let outerCornerRadius: CGFloat = 16.2
    static let innerCornerRadius: CGFloat = outerCornerRadius - padding
    
    static let shadowRadius: CGFloat = 2.5
    static let shadowOffset = CGSize(width: 0, height: 1)
    static let shadowColor = UIColor.black.withAlphaComponent(0.4).cgColor
    
    static let borderColor: UIColor = .white
    static let primaryColor: UIColor = UIColor(Color.primary400)
}

struct ClusterMarkerRenderer {
    static func render(_ text: String) -> UIImage {
        let bodySize = ClusteringLayout.imageSize + (ClusteringLayout.padding * 2)
        let shadowMargin = ClusteringLayout.shadowRadius * 4
        let sideLength = bodySize + shadowMargin * 2
        let canvasSize = CGSize(width: sideLength, height: sideLength)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            let drawOffsetX = shadowMargin
            let drawOffsetY = ClusteringLayout.shadowRadius
            
            let bodyRect = CGRect(
                x: drawOffsetX,
                y: drawOffsetY,
                width: bodySize,
                height: bodySize
            )
            
            let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: ClusteringLayout.outerCornerRadius)
            
            cgContext.saveGState()
            cgContext.setShadow(offset: ClusteringLayout.shadowOffset, blur: ClusteringLayout.shadowRadius, color: ClusteringLayout.shadowColor)
            UIColor.black.setFill()
            bodyPath.fill()
            cgContext.setBlendMode(.clear)
            bodyPath.fill()
            cgContext.restoreGState()
            
            cgContext.saveGState()
            ClusteringLayout.borderColor.setFill()
            bodyPath.fill()
            cgContext.restoreGState()
            
            let innerRect = CGRect(
                x: bodyRect.minX + ClusteringLayout.padding,
                y: bodyRect.minY + ClusteringLayout.padding,
                width: ClusteringLayout.imageSize,
                height: ClusteringLayout.imageSize
            )
            
            let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: ClusteringLayout.innerCornerRadius)
            
            cgContext.saveGState()
            ClusteringLayout.primaryColor.setFill()
            innerPath.fill()
            cgContext.restoreGState()
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.neki(.title20SemiBold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let text = text as NSString
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: innerRect.midX - (textSize.width / 2.0),
                y: innerRect.midY - (textSize.height / 2.0),
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}
