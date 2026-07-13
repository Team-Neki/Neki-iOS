//
//  MasonryColumnBuilder.swift
//  Neki-iOS
//
//  Created by Codex on 7/13/26.
//

enum MasonryColumnBuilder {
    static func emptyColumns<Item>(count: Int, itemCount: Int) -> [[Item]] {
        let count = max(1, count)
        var columns = Array(repeating: [Item](), count: count)
        let baseCapacity = itemCount / count
        let remainingCapacity = itemCount % count
        columns.indices.forEach {
            columns[$0].reserveCapacity(baseCapacity + ($0 < remainingCapacity ? 1 : 0))
        }
        return columns
    }
}
