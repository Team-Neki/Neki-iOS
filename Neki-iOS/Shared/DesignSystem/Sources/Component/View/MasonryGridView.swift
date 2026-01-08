//
//  MasonryGridView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/8/26.
//

// 📁 Module: DesignSystem (또는 CoreUI)
import SwiftUI

// 제네릭을 사용하여 어떤 데이터 모델(Item)이든 받을 수 있게 만듭니다.
public struct MasonryGridView<Item: Identifiable, ItemView: View>: View {
    
    let items: [Item] // 혹은 IdentifiedArray 등 컬렉션
    let columns: Int
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: (Item) -> ItemView // 각 아이템을 그리는 클로저
    
    public init(
        items: [Item],
        columns: Int = 2,
        horizontalSpacing: CGFloat = 10,
        verticalSpacing: CGFloat = 10,
        @ViewBuilder content: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.columns = columns
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content
    }
    
    // items를 컬럼 개수만큼 2차원 배열로 쪼개는 로직
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
