//
//  MasonryColumnsTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 11/16/26.
//

import Foundation
import Testing
@testable import Neki_iOS

struct MasonryColumnsTests {
    @Test("앞에서부터 높이 합이 가장 작은 열에 넣고, 합이 같으면 왼쪽 열에 넣는다")
    func assign_putsItemIntoShortestColumn() {
        let columns = MasonryColumns.assign(estimatedHeights: [1.0, 0.5, 0.5, 1.0, 0.3], columnCount: 2)

        #expect(columns == [0, 1, 1, 0, 1])
    }

    @Test("뒤에 항목이 붙어도 앞 항목의 열은 바뀌지 않는다")
    func assign_keepsEarlierColumns_whenItemsAreAppended() {
        let firstPage: [CGFloat] = [1.33, 0.75, 1.0, 1.25, 0.8]
        let nextPage: [CGFloat] = [1.5, 0.6, 1.1]

        let firstColumns = MasonryColumns.assign(estimatedHeights: firstPage, columnCount: 2)
        let allColumns = MasonryColumns.assign(estimatedHeights: firstPage + nextPage, columnCount: 2)

        #expect(Array(allColumns.prefix(firstPage.count)) == firstColumns)
    }

    @Test("열이 하나면 모든 항목을 첫 열에 넣는다")
    func assign_withSingleColumn_putsAllIntoFirstColumn() {
        #expect(MasonryColumns.assign(estimatedHeights: [1.0, 0.5, 2.0], columnCount: 1) == [0, 0, 0])
    }
}
