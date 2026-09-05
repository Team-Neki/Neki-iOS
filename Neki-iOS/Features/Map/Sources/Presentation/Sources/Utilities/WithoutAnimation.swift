//
//  WithoutAnimation.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/28/26.
//

import SwiftUI

/// 화면 전환 애니메이션 없이 상태를 변경합니다.
///
/// `fullScreenCover`나 `sheet`처럼 상태 변경 시점의 트랜잭션을 따라 전환하는 표현을
/// 애니메이션 없이 즉시 바꿔야 할 때 사용합니다.
///
/// - Important: 상태 변경이 이 클로저 안에서 **동기적으로** 일어나야 트랜잭션이 전달됩니다.
///   리듀서가 이펙트로 나중에 보낸 액션에는 적용되지 않습니다.
public func withoutAnimation(_ body: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, body)
}
