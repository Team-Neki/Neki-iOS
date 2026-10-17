//
//  BoothMarkerConfigurator.swift
//  Neki-iOS
//
//  Created by Codex on 10/17/26.
//

import CoreGraphics
import NMapsMap
import UIKit

/// 일반 마커와 중첩 분산 마커에 동일한 표시·충돌 정책을 적용합니다.
enum BoothMarkerConfigurator {
    static func configure(
        _ marker: NMFMarker,
        for booth: PhotoBooth,
        isSelected: Bool,
        captionColorHex: UInt,
        captionTextSize: CGFloat,
        normalZIndex: Int,
        selectedZIndex: Int
    ) {
        marker.userInfo["identifier"] = booth.id
        marker.captionText = "\(booth.brand.name)\n\(booth.name)"
        marker.captionColor = .init(hex: captionColorHex)
        marker.captionHaloColor = .white
        marker.captionAligns = [NMFAlignType.bottom]
        marker.captionTextSize = captionTextSize
        marker.captionOffset = -8
        marker.anchor = CGPoint(x: 0.5, y: 1.0)
        marker.zIndex = isSelected ? selectedZIndex : normalZIndex
        marker.isHideCollidedSymbols = true
        marker.isHideCollidedMarkers = false
        marker.isHideCollidedCaptions = true
        marker.isForceShowCaption = isSelected
    }
}
