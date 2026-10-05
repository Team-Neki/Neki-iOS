//
//  PhotoBoothDistanceLabel.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/5/26.
//

import SwiftUI
import Dependencies

/// Lazy 목록에서 필요한 셀의 거리만 표시합니다.
///
/// 정렬 또는 서버 응답에서 계산된 거리가 있으면 재사용합니다.
/// `.equatable()`과 함께 사용하여 동일 입력에 대한 계산과 문자열 변환을 줄입니다.
struct PhotoBoothDistanceLabel: View, Equatable {
    let coordinate: GeographicCoordinate
    let source: GeographicCoordinate?
    let measuredDistance: GeographicDistance?

    @Dependency(\.distanceFormatterClient) private var distanceFormatter
    
    init(
        coordinate: GeographicCoordinate,
        source: GeographicCoordinate?,
        measuredDistance: GeographicDistance?
    ) {
        self.coordinate = coordinate
        self.source = source
        self.measuredDistance = measuredDistance
    }

    var body: some View {
        if let text = distanceText {
            Rectangle()
                .fill(.gray100)
                .frame(width: 1, height: 10)

            Text(text)
                .nekiFont(.body14SemiBold)
                .foregroundStyle(.gray700)
                .fixedSize()
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.coordinate == rhs.coordinate && lhs.source == rhs.source && lhs.measuredDistance == rhs.measuredDistance
    }
}


// MARK: - PhotoBoothDistanceLabel + Presentation

private extension PhotoBoothDistanceLabel {
    var distanceText: String? {
        guard let distance = measuredDistance ?? source.map({ distanceFormatter.distance($0, coordinate) }),
              distance.meters.isFinite, distance.meters >= .zero else { return nil }
        let text = distanceFormatter.string(distance: distance)
        guard text.isEmpty == false else { return nil }
        return text
    }
}
