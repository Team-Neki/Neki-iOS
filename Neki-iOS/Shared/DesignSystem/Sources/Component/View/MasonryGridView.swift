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
    let items: [Item]
    let estimatedHeight: ((Item) -> CGFloat?)?
    let preferredColumn: ((Item) -> Int?)?
    let content: (Item) -> ItemView
    
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
        self.items = items
        self.estimatedHeight = estimatedHeight
        self.preferredColumn = nil
        self.content = content
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
        self.items = columnItems.flatMap { $0 }
        self.estimatedHeight = nil
        let preferredColumnByID = Dictionary(uniqueKeysWithValues: columnItems.enumerated().flatMap { index, column in
            column.map { ($0.id, index) }
        })
        self.preferredColumn = { preferredColumnByID[$0.id] }
        self.content = content
    }
    
    //MARK: - Main Body

    public var body: some View {
        MasonryGridLayout(
            columns: columns,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        ) {
            ForEach(items) { item in
                content(item)
                    .layoutValue(key: MasonryIdentityKey.self, value: AnyHashable(item.id))
                    .layoutValue(key: MasonryEstimatedHeightKey.self, value: estimatedHeight?(item))
                    .layoutValue(key: MasonryPreferredColumnKey.self, value: preferredColumn?(item))
            }
        }
    }
}

private struct MasonryGridLayout: Layout {
    struct Cache {
        var key: Key?
        var placements: [Placement] = []
        var size: CGSize = .zero
    }

    struct Key: Equatable {
        let subviewCount: Int
        let columnCount: Int
        let width: CGFloat
        let horizontalSpacing: CGFloat
        let verticalSpacing: CGFloat
        let identities: [AnyHashable?]
        let estimatedHeights: [CGFloat?]
        let preferredColumns: [Int?]
    }

    struct Placement {
        let origin: CGPoint
        let size: CGSize
    }

    let columns: Int
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.key = nil
        cache.placements.removeAll(keepingCapacity: true)
        cache.size = .zero
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        layout(proposal: proposal, subviews: subviews, cache: &cache).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let result = layout(proposal: .init(width: bounds.width, height: proposal.height), subviews: subviews, cache: &cache)
        for index in subviews.indices {
            guard result.placements.indices.contains(index) else { continue }
            let placement = result.placements[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + placement.origin.x, y: bounds.minY + placement.origin.y),
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Cache {
        let columnCount = max(1, columns)
        let proposedWidth = proposal.width ?? fallbackWidth(subviews: subviews, columnCount: columnCount)
        let availableWidth = max(.zero, proposedWidth)
        let columnWidth = columnWidth(containerWidth: availableWidth, columnCount: columnCount)
        let identities = subviews.map { $0[MasonryIdentityKey.self] }
        let estimatedHeights = subviews.map { $0[MasonryEstimatedHeightKey.self] }
        let preferredColumns = subviews.map { $0[MasonryPreferredColumnKey.self] }
        let key = Key(
            subviewCount: subviews.count,
            columnCount: columnCount,
            width: availableWidth,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing,
            identities: identities,
            estimatedHeights: estimatedHeights,
            preferredColumns: preferredColumns
        )

        guard cache.key != key else { return cache }

        var placements: [Placement] = []
        placements.reserveCapacity(subviews.count)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

        for index in subviews.indices {
            let columnIndex: Int
            if let preferredColumn = preferredColumns[index], preferredColumn >= .zero, preferredColumn < columnCount {
                columnIndex = preferredColumn
            } else {
                columnIndex = columnHeights
                    .enumerated()
                    .min(by: { $0.element < $1.element })?
                    .offset ?? .zero
            }

            let height = estimatedHeights[index].map { columnWidth * $0 } ?? subviews[index].sizeThatFits(.init(width: columnWidth, height: nil)).height
            let origin = CGPoint(
                x: CGFloat(columnIndex) * (columnWidth + horizontalSpacing),
                y: columnHeights[columnIndex]
            )
            let size = CGSize(width: columnWidth, height: height)
            placements.append(.init(origin: origin, size: size))
            columnHeights[columnIndex] += height + verticalSpacing
        }

        let maxHeight = max(.zero, (columnHeights.max() ?? .zero) - verticalSpacing)
        cache.key = key
        cache.placements = placements
        cache.size = CGSize(width: availableWidth, height: maxHeight)
        return cache
    }

    private func columnWidth(containerWidth: CGFloat, columnCount: Int) -> CGFloat {
        guard columnCount > 1 else { return containerWidth }
        let spacing = horizontalSpacing * CGFloat(columnCount - 1)
        return max(.zero, (containerWidth - spacing) / CGFloat(columnCount))
    }

    private func fallbackWidth(subviews: Subviews, columnCount: Int) -> CGFloat {
        let maxSubviewWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? .zero
        return maxSubviewWidth * CGFloat(columnCount) + horizontalSpacing * CGFloat(max(.zero, columnCount - 1))
    }
}

private struct MasonryEstimatedHeightKey: LayoutValueKey {
    static let defaultValue: CGFloat? = nil
}

private struct MasonryIdentityKey: LayoutValueKey {
    static let defaultValue: AnyHashable? = nil
}

private struct MasonryPreferredColumnKey: LayoutValueKey {
    static let defaultValue: Int? = nil
}
