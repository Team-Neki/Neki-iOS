//
//  PhotoEntity+Masonry.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/13/26.
//

import CoreGraphics

extension PhotoEntity {
    var masonryEstimatedHeight: CGFloat? {
        guard let width, let height, width > .zero, height > .zero else { return nil }
        return CGFloat(height) / CGFloat(width)
    }
}
