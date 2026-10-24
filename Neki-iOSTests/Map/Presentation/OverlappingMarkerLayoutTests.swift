//
//  OverlappingMarkerLayoutTests.swift
//  Neki-iOSTests
//
//  Created by Codex on 10/16/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Neki_iOS

struct OverlappingMarkerLayoutTests {
    private struct Marker {
        let id: String
        let coordinate: GeographicCoordinate
    }

    private let markerSize = CGSize(width: 52, height: 52)
    private let minimumGap: CGFloat = .zero
    private let coordinateDecimalPlaces = 5

    @Test("단독 마커는 원본 화면 좌표를 유지한다")
    func singleMarker_staysAtOrigin() {
        #expect(OverlappingMarkerLayout.offsets(count: 1, markerSize: markerSize, minimumGap: minimumGap) == [.zero])
    }

    @Test("동일 좌표 2·3·7·8개와 과밀 그룹의 상호작용 영역이 겹치지 않는다", arguments: [2, 3, 7, 8, 9, 24])
    func overlappingMarkers_keepInteractionFramesSeparated(count: Int) {
        let offsets = makeOffsets(count: count)
        let frames = offsets.map(markerFrame(at:))

        #expect(offsets.count == count)
        for firstIndex in frames.indices {
            for secondIndex in frames.indices where secondIndex > firstIndex {
                #expect(frames[firstIndex].intersects(frames[secondIndex]) == false)
            }
        }
    }

    @Test("같은 개수의 그룹은 매번 같은 배치를 사용한다")
    func sameCount_keepsStableLayout() {
        let first = makeOffsets(count: 8)
        let second = makeOffsets(count: 8)

        #expect(first == second)
    }

    @Test("8개를 넘으면 기존 위치를 반복하지 않고 바깥 원을 추가한다")
    func moreThanEightMarkers_addsOuterRing() {
        let offsets = makeOffsets(count: 9)
        let innerRadius = hypot(offsets[0].x, offsets[0].y)
        let outerRadius = hypot(offsets[8].x, offsets[8].y)

        #expect(Set(offsets.map { "\($0.x),\($0.y)" }).count == offsets.count)
        #expect(outerRadius > innerRadius)
    }

    @Test("분산 화면 오프셋은 고정된 지리 좌표로 변환한다")
    func markerOffsets_convertToStableCoordinates() {
        let origin = GeographicCoordinate(latitude: 37.4979, longitude: 127.0276)

        let first = OverlappingMarkerLayout.coordinates(
            origin: origin,
            count: 2,
            markerSize: markerSize,
            minimumGap: minimumGap,
            zoomLevel: 19
        )
        let second = OverlappingMarkerLayout.coordinates(
            origin: origin,
            count: 2,
            markerSize: markerSize,
            minimumGap: minimumGap,
            zoomLevel: 19
        )

        #expect(first == second)
        #expect(Set(first).count == 2)
        #expect(first.allSatisfy { coordinateDistance(from: origin, to: $0) < 20 })
    }

    @Test("응답 순서가 달라도 같은 좌표 그룹의 ID 배치 순서는 유지된다")
    func reorderedInput_keepsIDBasedOrder() {
        let coordinate = GeographicCoordinate(latitude: 37.4979, longitude: 127.0276)
        let first = [
            Marker(id: "source:C:3", coordinate: coordinate),
            Marker(id: "source:A:1", coordinate: coordinate),
            Marker(id: "source:B:2", coordinate: coordinate)
        ]
        let second = [first[1], first[2], first[0]]

        let firstGroups = groups(first)
        let secondGroups = groups(second)

        #expect(firstGroups == secondGroups)
        #expect(firstGroups[coordinate] == ["source:A:1", "source:B:2", "source:C:3"])
    }

    @Test("소수점 전체 값이 달라도 정규화 좌표가 같으면 같은 그룹으로 묶는다")
    func nearbyCoordinates_joinSameGroup() {
        let markers = [
            Marker(id: "A", coordinate: GeographicCoordinate(latitude: 37.4979000, longitude: 127.0276000)),
            Marker(id: "B", coordinate: GeographicCoordinate(latitude: 37.4979001, longitude: 127.0276001))
        ]

        #expect(groups(markers).values.first == ["A", "B"])
    }

    @Test("정규화 좌표가 다른 지점은 별도 그룹으로 유지한다")
    func separatedCoordinates_stayInDifferentGroups() {
        let markers = [
            Marker(id: "A", coordinate: GeographicCoordinate(latitude: 37.4979, longitude: 127.0276)),
            Marker(id: "B", coordinate: GeographicCoordinate(latitude: 37.49792, longitude: 127.02762))
        ]

        #expect(groups(markers).isEmpty)
    }

    @Test("마커와 무관한 상세 정보 변경은 표현 상태를 갱신하지 않는다")
    func nonVisualBoothChanges_keepMarkerPresentationState() {
        let original = makePhotoBooth(address: "기존 주소", nearbyDistance: nil)
        let changed = makePhotoBooth(address: "변경된 주소", nearbyDistance: GeographicDistance(meters: 120))

        #expect(PhotoBoothMarkerPresentationState(booth: original) == PhotoBoothMarkerPresentationState(booth: changed))
    }

    @Test("즐겨찾기 변경은 마커 표현 상태를 갱신한다")
    func favoriteChange_updatesMarkerPresentationState() {
        let normal = makePhotoBooth(isFavorite: false)
        let favorite = makePhotoBooth(isFavorite: true)

        #expect(PhotoBoothMarkerPresentationState(booth: normal) != PhotoBoothMarkerPresentationState(booth: favorite))
    }

    private func groups(_ markers: [Marker]) -> [GeographicCoordinate: [String]] {
        OverlappingMarkerGroupResolver.groups(
            elements: markers,
            id: \.id,
            coordinate: \.coordinate,
            coordinateDecimalPlaces: coordinateDecimalPlaces
        )
    }

    private func makeOffsets(count: Int) -> [CGPoint] {
        OverlappingMarkerLayout.offsets(count: count, markerSize: markerSize, minimumGap: minimumGap)
    }

    private func markerFrame(at offset: CGPoint) -> CGRect {
        CGRect(
            x: offset.x - markerSize.width / 2,
            y: offset.y - markerSize.height,
            width: markerSize.width,
            height: markerSize.height
        )
        .insetBy(dx: -minimumGap / 2, dy: -minimumGap / 2)
    }

    private func coordinateDistance(
        from start: GeographicCoordinate,
        to end: GeographicCoordinate
    ) -> Double {
        let earthRadius = 6_378_137.0
        let latitudeDelta = (end.latitude - start.latitude) * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let meanLatitude = (start.latitude + end.latitude) / 2 * .pi / 180
        let northMeters = latitudeDelta * earthRadius
        let eastMeters = longitudeDelta * earthRadius * cos(meanLatitude)
        return hypot(northMeters, eastMeters)
    }

    private func makePhotoBooth(
        address: String = "주소",
        nearbyDistance: GeographicDistance? = nil,
        isFavorite: Bool = false
    ) -> PhotoBooth {
        PhotoBooth(
            id: "source:A:1",
            brand: PhotoBoothBrand(
                id: 1,
                name: "브랜드",
                englishName: "Brand",
                imageURL: URL(string: "https://example.com/brand.png")
            ),
            name: "강남점",
            coordinate: GeographicCoordinate(latitude: 37.4979, longitude: 127.0276),
            address: address,
            nearbyDistance: nearbyDistance,
            isFavorite: isFavorite
        )
    }
}
