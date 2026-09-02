//
//  PhotoBoothQueryBoundsExpander.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/30/26.
//

import Foundation

/// 지도 Viewport를 기존 POI 선조회 범위와 동일한 타일 경계까지 확장합니다.
enum PhotoBoothQueryBoundsExpander {
    private struct TileCoordinate {
        let x: Int
        let y: Int
    }

    /// 타일 분할 조회에서 사용하던 z15 경계를 유지해 화면 가장자리 바깥 POI까지 한 번에 요청합니다.
    private static let coverageZoomLevel: Int = 15

    static func expandedBounds(for bounds: GeographicBoundingBox) -> GeographicBoundingBox {
        let northWestTile = tileCoordinate(
            for: GeographicCoordinate(latitude: bounds.maxLatitude, longitude: bounds.minLongitude)
        )
        let southEastTile = tileCoordinate(
            for: GeographicCoordinate(latitude: bounds.minLatitude, longitude: bounds.maxLongitude)
        )
        let tileScale = pow(2.0, Double(coverageZoomLevel))
        let west = longitude(forTileX: northWestTile.x, scale: tileScale)
        let east = longitude(forTileX: southEastTile.x + 1, scale: tileScale)
        let north = latitude(forTileY: northWestTile.y, scale: tileScale)
        let south = latitude(forTileY: southEastTile.y + 1, scale: tileScale)

        return GeographicBoundingBox(
            minLatitude: min(south, bounds.minLatitude),
            minLongitude: west,
            maxLatitude: max(north, bounds.maxLatitude),
            maxLongitude: east
        )
    }
}


// MARK: - PhotoBoothQueryBoundsExpander + Helpers

private extension PhotoBoothQueryBoundsExpander {
    private static func tileCoordinate(for coordinate: GeographicCoordinate) -> TileCoordinate {
        let tileScale = pow(2.0, Double(coverageZoomLevel))
        let lastTileIndex = Int(tileScale) - 1
        let x = min(Int((coordinate.longitude + 180.0) / 360.0 * tileScale), lastTileIndex)
        // 극점은 Mercator 투영이 불가능하므로 타일 인덱스만 투영 한계로 제한하고 원본 조회 위도는 유지합니다.
        let maximumLatitude = latitude(forTileY: .zero, scale: tileScale)
        let projectedLatitude = min(max(coordinate.latitude, -maximumLatitude), maximumLatitude)
        let latitudeRadians = projectedLatitude * .pi / 180.0
        let projectedY = (1.0 - log(tan(latitudeRadians) + 1.0 / cos(latitudeRadians)) / .pi) / 2.0 * tileScale
        let y = min(max(Int(projectedY), .zero), lastTileIndex)
        return TileCoordinate(x: x, y: y)
    }

    static func longitude(forTileX x: Int, scale: Double) -> Double {
        Double(x) / scale * 360.0 - 180.0
    }

    static func latitude(forTileY y: Int, scale: Double) -> Double {
        atan(sinh(.pi * (1.0 - 2.0 * Double(y) / scale))) * 180.0 / .pi
    }
}
