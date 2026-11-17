//
//  LazyMasonryGridView.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 11/16/26.
//

import SwiftUI

/// 화면 근처의 카드만 만드는 마소너리 그리드입니다.
///
/// `MasonryGridView`처럼 카드를 덜 찬 열에 차례로 넣지만, 열마다 `LazyVStack`으로 그려 화면에서 먼 카드는 만들지 않습니다.
/// 그래서 카드의 `onAppear`가 스크롤에 맞춰 불리고, 카드 안의 이미지도 화면 근처에서만 받습니다.
public struct LazyMasonryGridView<Item: Identifiable, ItemView: View>: View {
    
    //MARK: - Properties
    
    let columns: Int
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let items: [Item]
    let estimatedHeight: (Item) -> CGFloat
    let content: (Item) -> ItemView
    
    //MARK: - init
    
    /// - Parameter estimatedHeight: 카드 높이를 열 폭에 대한 비율(높이 ÷ 폭)로 돌려줍니다.
    ///   화면 밖 카드는 아직 만들지 않아 잴 수 없으므로 모든 카드에 값이 있어야 합니다. 열을 고를 때만 쓰고, 실제 높이는 카드가 정합니다.
    public init(
        items: [Item],
        columns: Int = 2,
        horizontalSpacing: CGFloat = 12,
        verticalSpacing: CGFloat = 12,
        estimatedHeight: @escaping (Item) -> CGFloat,
        @ViewBuilder content: @escaping (Item) -> ItemView
    ) {
        self.columns = max(1, columns)
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.items = items
        self.estimatedHeight = estimatedHeight
        self.content = content
    }
    
    //MARK: - Main Body
    
    public var body: some View {
        let columnItems = self.columnItems
        HStack(alignment: .top, spacing: horizontalSpacing) {
            ForEach(columnItems.indices, id: \.self) { column in
                LazyVStack(spacing: verticalSpacing) {
                    ForEach(columnItems[column]) { item in
                        content(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
    
    private var columnItems: [[Item]] {
        let assignedColumns = MasonryColumns.assign(estimatedHeights: items.map(estimatedHeight), columnCount: columns)
        var columnItems = Array(repeating: [Item](), count: columns)
        for (item, column) in zip(items, assignedColumns) {
            columnItems[column].append(item)
        }
        return columnItems
    }
}


// MARK: - MasonryColumns

/// 마소너리 그리드의 열 배치 규칙입니다.
enum MasonryColumns {
    /// 앞에서부터 높이 합이 가장 작은 열(같으면 왼쪽)에 넣고, 항목마다 열 번호를 돌려줍니다.
    ///
    /// 뒤에 항목이 붙어도 앞 항목의 열은 바뀌지 않아, 다음 페이지를 붙일 때 이미 있던 카드가 다른 열로 옮겨 가지 않습니다.
    /// 카드 사이 간격은 높이 합에 넣지 않습니다.
    static func assign(estimatedHeights: [CGFloat], columnCount: Int) -> [Int] {
        var columnHeights = Array(repeating: CGFloat.zero, count: max(1, columnCount))
        return estimatedHeights.map { height in
            let column = columnHeights.indices.min { columnHeights[$0] < columnHeights[$1] } ?? .zero
            columnHeights[column] += height
            return column
        }
    }
}
