//
//  MasonryGridView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/8/26.
//

import SwiftUI

public struct MasonryGridView<Item: Identifiable, ItemView: View>: View {
    
    let items: [Item]
    let columns: Int
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: (Item) -> ItemView
    
    public init(
        items: [Item],
        columns: Int = 2,
        horizontalSpacing: CGFloat = 12,
        verticalSpacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.columns = columns
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content
    }
    
    private var columnItems: [[Item]] {
        var result = Array(repeating: [Item](), count: columns)
        for (index, item) in items.enumerated() {
            result[index % columns].append(item)
        }
        return result
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: horizontalSpacing) {
            ForEach(0..<columns, id: \.self) { columnIndex in
                LazyVStack(spacing: verticalSpacing) {
                    ForEach(columnItems[columnIndex]) { item in
                        content(item)
                    }
                }
            }
        }
    }
}
