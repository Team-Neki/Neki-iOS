//
//  OverlappingMarkerLayout.swift
//  Neki-iOS
//
//  Created by Codex on 10/16/26.
//

import CoreGraphics

/// 원본 좌표가 정확히 같은 항목만 묶고, 식별자 순서로 안정화합니다.
enum OverlappingMarkerGroupResolver {
    static func groups<Element, ID: Hashable & Comparable, Coordinate: Hashable>(
        elements: some Sequence<Element>,
        id: (Element) -> ID,
        coordinate: (Element) -> Coordinate
    ) -> [Coordinate: [ID]] {
        let grouped = Dictionary(grouping: elements, by: coordinate)
        return grouped.reduce(into: [:]) { result, entry in
            guard entry.value.count > 1 else { return }
            result[entry.key] = entry.value.map(id).sorted()
        }
    }
}

/// 같은 화면 좌표에서 시작하는 마커의 아이콘 영역을 서로 떨어뜨리는 순수 배치 로직입니다.
///
/// 지도 SDK의 투영과 역투영은 호출부가 담당하고, 이 타입은 화면 좌표 오프셋만 계산합니다.
enum OverlappingMarkerLayout {
    /// 첫 번째 원에 배치할 최대 마커 수입니다.
    /// 2~3개의 일반적인 중첩은 작은 원 하나로 처리하고, 과밀 그룹은 여러 원으로 확장합니다.
    private static let firstRingCapacity = 8

    static func offsets(count: Int, markerSize: CGSize, minimumGap: CGFloat) -> [CGPoint] {
        guard count > 1,
              markerSize.width.isFinite,
              markerSize.height.isFinite,
              markerSize.width > .zero,
              markerSize.height > .zero,
              minimumGap.isFinite,
              minimumGap >= .zero
        else {
            return count == 1 ? [.zero] : []
        }

        var result: [CGPoint] = []
        result.reserveCapacity(count)

        var remainingCount = count
        var ringIndex = 0

        while remainingCount > .zero {
            let capacity = firstRingCapacity * (ringIndex + 1)
            let itemCount = min(remainingCount, capacity)
            let startAngle = -.pi / 2 + (ringIndex.isMultiple(of: 2) ? .zero : .pi / Double(itemCount))
            let radius = minimumRadius(
                itemCount: itemCount,
                startAngle: startAngle,
                markerSize: markerSize,
                minimumGap: minimumGap,
                existingOffsets: result
            )
            result.append(contentsOf: offsets(count: itemCount, radius: radius, startAngle: startAngle))

            remainingCount -= itemCount
            ringIndex += 1
        }

        return result
    }

    private static func minimumRadius(
        itemCount: Int,
        startAngle: Double,
        markerSize: CGSize,
        minimumGap: CGFloat,
        existingOffsets: [CGPoint]
    ) -> CGFloat {
        var lowerBound: CGFloat = .zero
        var upperBound = max(markerSize.width, markerSize.height)

        while hasCollision(
            offsets: existingOffsets + offsets(
                count: itemCount,
                radius: upperBound,
                startAngle: startAngle
            ),
            markerSize: markerSize,
            minimumGap: minimumGap
        ) {
            upperBound *= 2
        }

        for _ in 0..<20 {
            let candidate = (lowerBound + upperBound) / 2
            let candidateOffsets = existingOffsets + offsets(count: itemCount, radius: candidate, startAngle: startAngle)
            if hasCollision(offsets: candidateOffsets, markerSize: markerSize, minimumGap: minimumGap) {
                lowerBound = candidate
            } else {
                upperBound = candidate
            }
        }

        return upperBound
    }

    private static func offsets(count: Int, radius: CGFloat, startAngle: Double) -> [CGPoint] {
        (0..<count).map { index in
            let angle = startAngle + 2 * .pi * Double(index) / Double(count)
            return CGPoint(x: radius * CGFloat(cos(angle)), y: radius * CGFloat(sin(angle)))
        }
    }

    private static func hasCollision(
        offsets: [CGPoint],
        markerSize: CGSize,
        minimumGap: CGFloat
    ) -> Bool {
        let frames = offsets.map {
            // NMFMarker의 기본 앵커 (0.5, 1.0)를 기준으로 실제 아이콘 영역을 계산합니다.
            CGRect(
                x: $0.x - markerSize.width / 2,
                y: $0.y - markerSize.height,
                width: markerSize.width,
                height: markerSize.height
            )
            .insetBy(dx: -minimumGap / 2, dy: -minimumGap / 2)
        }

        for firstIndex in frames.indices {
            for secondIndex in frames.indices where secondIndex > firstIndex {
                if frames[firstIndex].intersects(frames[secondIndex]) { return true }
            }
        }
        return false
    }
}
