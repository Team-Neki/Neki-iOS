//
//  OverlappingMarkerLayout.swift
//  Neki-iOS
//
//  Created by Codex on 10/16/26.
//

import CoreGraphics

/// 가까운 원본 좌표를 같은 위치로 묶고, 식별자 순서로 안정화합니다.
enum OverlappingMarkerGroupResolver {
    private static let earthRadius: Double = 6_378_137

    static func groups<Element, ID: Hashable & Comparable>(
        elements: some Sequence<Element>,
        id: (Element) -> ID,
        coordinate: (Element) -> GeographicCoordinate,
        maximumDistanceMeters: Double
    ) -> [GeographicCoordinate: [ID]] {
        guard maximumDistanceMeters.isFinite, maximumDistanceMeters >= .zero else { return [:] }

        let candidates = elements.map { (id: id($0), coordinate: coordinate($0)) }
        guard candidates.count > 1 else { return [:] }

        let latitudeThreshold = maximumDistanceMeters / earthRadius * 180 / .pi
        let indicesByLatitude = candidates.indices.sorted {
            candidates[$0].coordinate.latitude < candidates[$1].coordinate.latitude
        }
        var parents = Array(candidates.indices)

        func root(of index: Int) -> Int {
            var current = index
            while parents[current] != current { current = parents[current] }
            return current
        }

        func join(_ firstIndex: Int, _ secondIndex: Int) {
            let firstRoot = root(of: firstIndex)
            let secondRoot = root(of: secondIndex)
            guard firstRoot != secondRoot else { return }
            parents[secondRoot] = firstRoot
        }

        for (offset, firstIndex) in indicesByLatitude.enumerated() {
            for secondIndex in indicesByLatitude.dropFirst(offset + 1) {
                let latitudeDelta = candidates[secondIndex].coordinate.latitude
                    - candidates[firstIndex].coordinate.latitude
                if latitudeDelta > latitudeThreshold { break }
                if distance(
                    from: candidates[firstIndex].coordinate,
                    to: candidates[secondIndex].coordinate
                ) <= maximumDistanceMeters {
                    join(firstIndex, secondIndex)
                }
            }
        }

        let groupedIndices = Dictionary(grouping: candidates.indices, by: { root(of: $0) })
        return groupedIndices.values.reduce(into: [:]) { result, indices in
            guard indices.count > 1 else { return }
            let sortedIndices = indices.sorted { candidates[$0].id < candidates[$1].id }
            guard let originIndex = sortedIndices.first else { return }
            result[candidates[originIndex].coordinate] = sortedIndices.map { candidates[$0].id }
        }
    }

    private static func distance(
        from start: GeographicCoordinate,
        to end: GeographicCoordinate
    ) -> Double {
        let latitudeDelta = (end.latitude - start.latitude) * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let meanLatitude = (start.latitude + end.latitude) / 2 * .pi / 180
        let northMeters = latitudeDelta * earthRadius
        let eastMeters = longitudeDelta * earthRadius * cos(meanLatitude)
        return hypot(northMeters, eastMeters)
    }
}

/// 가까운 위치에서 시작하는 마커의 상호작용 영역을 서로 떨어뜨리고 고정 지리 좌표로 변환합니다.
enum OverlappingMarkerLayout {
    private static let earthRadius: Double = 6_378_137
    private static let tileSize: Double = 256

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

    /// 지정한 줌에서 화면 오프셋과 일치하는 고정 지리 좌표를 계산합니다.
    static func coordinates(
        origin: GeographicCoordinate,
        count: Int,
        markerSize: CGSize,
        minimumGap: CGFloat,
        zoomLevel: Double
    ) -> [GeographicCoordinate] {
        guard zoomLevel.isFinite else { return [] }

        let offsets = offsets(count: count, markerSize: markerSize, minimumGap: minimumGap)
        let latitudeRadians = origin.latitude * .pi / 180
        let metersPerPoint = 2 * .pi * earthRadius * cos(latitudeRadians)
            / (tileSize * pow(2, zoomLevel))

        return offsets.map { offset in
            let northMeters = -Double(offset.y) * metersPerPoint
            let eastMeters = Double(offset.x) * metersPerPoint
            let latitude = origin.latitude + northMeters / earthRadius * 180 / .pi
            let longitude = origin.longitude
                + eastMeters / (earthRadius * cos(latitudeRadians)) * 180 / .pi
            return GeographicCoordinate(latitude: latitude, longitude: longitude)
        }
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
            // NMFMarker의 기본 앵커 (0.5, 1.0)를 기준으로 상호작용 영역을 계산합니다.
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
