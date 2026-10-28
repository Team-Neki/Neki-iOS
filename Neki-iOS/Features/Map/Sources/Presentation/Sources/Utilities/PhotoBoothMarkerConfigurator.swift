//
//  PhotoBoothMarkerConfigurator.swift
//  Neki-iOS
//
//  Created by Codex on 10/17/26.
//

import CoreGraphics
import NMapsMap
import UIKit

struct PhotoBoothMarkerStyle {
    let captionColorHex: UInt
    let captionTextSize: CGFloat
    let normalZIndex: Int
    let selectedZIndex: Int
}

/// 하나의 포토부스를 나타내는 마커의 전체 표시 상태를 설정합니다.
enum PhotoBoothMarkerConfigurator {
    static func configure(
        _ marker: NMFMarker,
        for booth: PhotoBooth,
        isSelected: Bool,
        style: PhotoBoothMarkerStyle
    ) {
        marker.userInfo = ["identifier": booth.id]
        marker.captionText = "\(booth.brand.name)\n\(booth.name)"
        marker.captionColor = .init(hex: style.captionColorHex)
        marker.captionHaloColor = .white
        marker.captionAligns = [NMFAlignType.bottom]
        marker.captionTextSize = style.captionTextSize
        marker.captionOffset = -8
        marker.anchor = CGPoint(x: 0.5, y: 1.0)
        marker.zIndex = isSelected ? style.selectedZIndex : style.normalZIndex
        marker.isHideCollidedSymbols = true
        marker.isHideCollidedMarkers = false
        marker.isHideCollidedCaptions = false
        marker.isForceShowCaption = false
    }
}
