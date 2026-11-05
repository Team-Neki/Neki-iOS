//
//  Collection+.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 10/30/26.
//

import Foundation

extension Collection {
    /// 인덱스가 범위 안이면 그 원소를, 벗어나면 `nil`을 돌려줍니다.
    ///
    /// 범위를 벗어나는 것이 정상인 경우(비어 있을 수 있는 순위 등)에만 씁니다. 벗어나면 버그인 곳은 기존 서브스크립트로 바로 드러나게 둡니다.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
