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
            minLatitude: south,
            minLongitude: west,
            maxLatitude: north,
            maxLongitude: east
        )
    }
}


// MARK: - PhotoBoothQueryBoundsExpander + Helpers

private extension PhotoBoothQueryBoundsExpander {
    private static func tileCoordinate(for coordinate: GeographicCoordinate) -> TileCoordinate {
        let tileScale = pow(2.0, Double(coverageZoomLevel))
        let x = Int((coordinate.longitude + 180.0) / 360.0 * tileScale)
        let latitudeRadians = coordinate.latitude * .pi / 180.0
        let y = Int((1.0 - log(tan(latitudeRadians) + 1.0 / cos(latitudeRadians)) / .pi) / 2.0 * tileScale)
        return TileCoordinate(x: x, y: y)
    }

    static func longitude(forTileX x: Int, scale: Double) -> Double {
        Double(x) / scale * 360.0 - 180.0
    }

    static func latitude(forTileY y: Int, scale: Double) -> Double {
        atan(sinh(.pi * (1.0 - 2.0 * Double(y) / scale))) * 180.0 / .pi
    }
}
