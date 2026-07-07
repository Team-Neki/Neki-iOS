//
//  MasonryGridView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/8/26.
//

import SwiftUI

public struct MasonryGridView<Item: Identifiable, ItemView: View>: View {
    
    //MARK: - Properties

    let columns: Int
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: (Item) -> ItemView
    let columnItems: [[Item]]
    
    //MARK: - init
    
    public init(
        items: [Item],
        columns: Int = 2,
        horizontalSpacing: CGFloat = 12,
        verticalSpacing: CGFloat = 12,
        estimatedHeight: ((Item) -> CGFloat?)? = nil,
        @ViewBuilder content: @escaping (Item) -> ItemView
    ) {
        self.columns = max(1, columns)
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content

        guard let estimatedHeight else {
            var result = Array(repeating: [Item](), count: self.columns)
            for (index, item) in items.enumerated() {
                result[index % self.columns].append(item)
            }
            self.columnItems = result
            return
        }

        var result = Array(repeating: [Item](), count: self.columns)
        var columnHeights = Array(repeating: CGFloat.zero, count: self.columns)

        for item in items {
            let columnIndex = columnHeights
                .enumerated()
                .min(by: { $0.element < $1.element })?
                .offset ?? .zero
            result[columnIndex].append(item)
            columnHeights[columnIndex] += (estimatedHeight(item) ?? 1) + verticalSpacing
        }

        self.columnItems = result
    }

    public init(
        columnItems: [[Item]],
        horizontalSpacing: CGFloat = 12,
        verticalSpacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Item) -> ItemView
    ) {
        self.columns = max(1, columnItems.count)
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content
        self.columnItems = columnItems.isEmpty ? [[]] : columnItems
    }
    
    //MARK: - Main Body

    public var body: some View {
        HStack(alignment: .top, spacing: horizontalSpacing) {
            ForEach(0..<columns, id: \.self) { columnIndex in
                LazyVStack(spacing: verticalSpacing) {
                    ForEach(columnItems[columnIndex]) { item in
                        content(item)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
