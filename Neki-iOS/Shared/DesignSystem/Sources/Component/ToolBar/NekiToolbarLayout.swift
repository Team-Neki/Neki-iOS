//
//  NekiToolbarLayout.swift
//  Neki-iOS
//
//  Created by SwainYun on 4/19/26.
//

import SwiftUI

public struct NekiToolbarLayout<Left: View, Center: View, Right: View>: View {
    let left: Left
    let center: Center
    let right: Right
    let backgroundColor: Color
    
    public init(
        backgroundColor: Color = .white,
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right
    ) {
        self.backgroundColor = backgroundColor
        self.left = left()
        self.center = center()
        self.right = right()
    }
    
    public var body: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center, spacing: 0) {
                left
                Spacer()
                right
            }
            .padding(.leading, 8)
            .padding(.trailing, 20)
            .frame(height: 54)
            
            center
        }
        .background(backgroundColor)
        .frame(height: 54)
    }
}
