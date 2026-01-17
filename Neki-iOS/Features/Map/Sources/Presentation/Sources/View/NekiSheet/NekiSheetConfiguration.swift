//
//  NekiSheetConfiguration.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/28/25.
//

import SwiftUI

struct NekiSheetConfiguration: Equatable {
    var detents: Set<NekiSheetDetent>
    var cornerRadius: CGFloat
    var indicatorSize: CGSize
    var indicatorColor: Color
    var backgroundColor: Color
    var shadowColor: Color
    var shadowRadius: CGFloat
    var bottomInset: CGFloat
    var animation: Animation
    
    init(
        detents: Set<NekiSheetDetent> = [.large, .fraction(0.305), .fraction(0.134), .hidden],
        cornerRadius: CGFloat = 20,
        indicatorSize: CGSize = .init(width: 40, height: 5),
        indicatorColor: Color = .gray.opacity(0.4),
        backgroundColor: Color = .white,
        shadowColor: Color = .black.opacity(0.1),
        shadowRadius: CGFloat = 10,
        bottomInset: CGFloat = .zero,
        animation: Animation = .interpolatingSpring(stiffness: 300, damping: 30)
    ) {
        self.detents = detents
        self.cornerRadius = cornerRadius
        self.indicatorSize = indicatorSize
        self.indicatorColor = indicatorColor
        self.backgroundColor = backgroundColor
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.bottomInset = bottomInset
        self.animation = animation
    }
}

struct NekiSheetConfigurationKey: EnvironmentKey {
    typealias Value = NekiSheetConfiguration
    
    static let defaultValue: Value = .init()
}

extension EnvironmentValues {
    var sheetConfiguration: NekiSheetConfiguration {
        get { self[NekiSheetConfigurationKey.self] }
        set { self[NekiSheetConfigurationKey.self] = newValue }
    }
}
