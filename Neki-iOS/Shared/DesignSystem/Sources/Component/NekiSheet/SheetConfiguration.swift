//
//  SheetConfiguration.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/28/25.
//

import SwiftUI

struct SheetConfiguration: Equatable {
    var detents: Set<Detent>
    var cornerRadius: CGFloat
    var indicatorSize: CGSize
    var indicatorColor: Color
    var backgroundColor: Color
    var shadowColor: Color
    var shadowRadius: CGFloat
    var animation: Animation
    
    init(
        detents: Set<Detent> = [.absolute(100), .medium, .fraction(0.9)],
        cornerRadius: CGFloat = 20,
        indicatorSize: CGSize = .init(width: 40, height: 5),
        indicatorColor: Color = .gray.opacity(0.4),
        backgroundColor: Color = .white,
        shadowColor: Color = .black.opacity(0.1),
        shadowRadius: CGFloat = 10,
        animation: Animation = .interpolatingSpring(stiffness: 300, damping: 30)
    ) {
        self.detents = detents
        self.cornerRadius = cornerRadius
        self.indicatorSize = indicatorSize
        self.indicatorColor = indicatorColor
        self.backgroundColor = backgroundColor
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.animation = animation
    }
}

struct SheetConfigurationKey: EnvironmentKey {
    typealias Value = SheetConfiguration
    
    static let defaultValue: Value = .init()
}

extension EnvironmentValues {
    var sheetConfiguration: SheetConfiguration {
        get { self[SheetConfigurationKey.self] }
        set { self[SheetConfigurationKey.self] = newValue }
    }
}
