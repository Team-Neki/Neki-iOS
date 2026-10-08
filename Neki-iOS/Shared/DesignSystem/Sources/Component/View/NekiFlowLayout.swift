//
//  NekiFlowLayout.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 9/8/26.
//

import SwiftUI

/// 자식 뷰를 왼쪽부터 가로로 놓다가 폭이 모자라면 다음 줄로 넘기는 레이아웃입니다.
///
/// 칩처럼 폭이 제각각인 항목을 줄바꿈해 나열할 때 씁니다. 각 자식은 자신이 원하는 크기 그대로 놓입니다.
public struct NekiFlowLayout: Layout {
    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat

    /// - Parameters:
    ///   - horizontalSpacing: 같은 줄에 놓인 항목 사이의 간격
    ///   - verticalSpacing: 줄과 줄 사이의 간격
    public init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, in: proposal.width ?? .infinity).size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(subviews, in: bounds.width)

        for (subview, origin) in zip(subviews, arrangement.origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }
}


// MARK: - NekiFlowLayout + Helper

private extension NekiFlowLayout {
    struct Arrangement {
        var origins: [CGPoint] = []
        var size: CGSize = .zero
    }

    /// 주어진 폭 안에서 각 자식이 놓일 위치와 전체 크기를 계산합니다.
    ///
    /// 한 줄에 하나도 놓이지 않은 상태에서는 폭이 넘쳐도 첫 항목을 그 줄에 둡니다.
    func arrange(_ subviews: Subviews, in availableWidth: CGFloat) -> Arrangement {
        var arrangement = Arrangement()
        var cursor: CGPoint = .zero
        var lineHeight: CGFloat = .zero

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let isLineStart = cursor.x == .zero

            if isLineStart == false, cursor.x + size.width > availableWidth {
                cursor.x = .zero
                cursor.y += lineHeight + verticalSpacing
                lineHeight = .zero
            }

            arrangement.origins.append(cursor)
            lineHeight = max(lineHeight, size.height)
            arrangement.size.width = max(arrangement.size.width, cursor.x + size.width)
            cursor.x += size.width + horizontalSpacing
        }

        arrangement.size.height = subviews.isEmpty ? .zero : cursor.y + lineHeight
        return arrangement
    }
}
