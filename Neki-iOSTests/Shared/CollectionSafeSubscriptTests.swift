//
//  CollectionSafeSubscriptTests.swift
//  Neki-iOSTests
//
//  Created by J.H. Moon on 10/30/26.
//

import Testing
@testable import Neki_iOS

struct CollectionSafeSubscriptTests {
    @Test("범위 안의 인덱스면 그 원소를 돌려준다")
    func safeSubscript_withinBounds_returnsElement() {
        let values = ["하루필름", "포토이즘", "인생네컷"]

        #expect(values[safe: 0] == "하루필름")
        #expect(values[safe: 2] == "인생네컷")
    }

    @Test("범위를 벗어난 인덱스면 nil을 돌려준다", arguments: [-1, 3])
    func safeSubscript_outOfBounds_returnsNil(index: Int) {
        let values = ["하루필름", "포토이즘", "인생네컷"]

        #expect(values[safe: index] == nil)
    }

    @Test("빈 컬렉션이면 nil을 돌려준다")
    func safeSubscript_empty_returnsNil() {
        let values: [String] = []

        #expect(values[safe: 0] == nil)
    }

    @Test("위치가 아니라 컬렉션의 인덱스로 찾는다. 1부터 시작하는 슬라이스에서 0은 범위 밖이다")
    func safeSubscript_slice_usesCollectionIndices() {
        let slice = ["하루필름", "포토이즘", "인생네컷"][1...]

        #expect(slice[safe: 0] == nil)
        #expect(slice[safe: 1] == "포토이즘")
    }
}
