//
//  PhotoBoothTileCache.swift
//  Neki-iOS
//
//  Created by Codex on 8/1/26.
//

import Foundation

/// 지도 타일별 포토부스 조회 결과와 캐시 메타데이터를 보관합니다.
///
/// 조회 시 주입된 신선도 정책을 적용하여 데이터를 구분하며,
/// 데이터 갱신과 fallback 사용 여부는 Repository급에서 결정합니다.
final class PhotoBoothTileCache {
    private final class Key: NSObject {
        let tile: MapTile

        init(tile: MapTile) {
            self.tile = tile
        }

        override var hash: Int { tile.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Key else { return false }
            return tile == other.tile
        }
    }

    private final class Entry {
        let snapshot: PhotoBoothTileCacheSnapshot

        init(snapshot: PhotoBoothTileCacheSnapshot) {
            self.snapshot = snapshot
        }
    }

    private let storage: NSCache<Key, Entry>
    private let freshnessPolicy: any PhotoBoothCacheFreshnessPolicy

    init(configuration: PhotoBoothCacheConfiguration) {
        let storage = NSCache<Key, Entry>()
        storage.countLimit = configuration.maximumTileCount
        storage.totalCostLimit = configuration.maximumPhotoBoothCount
        self.storage = storage
        freshnessPolicy = configuration.freshnessPolicy
    }

    func lookup(tile: MapTile, now: Date) -> PhotoBoothTileCacheLookup {
        guard let entry = storage.object(forKey: Key(tile: tile)) else { return .missing }
        guard freshnessPolicy.isFresh(metadata: entry.snapshot.metadata, now: now) else { return .stale(entry.snapshot) }
        return .fresh(entry.snapshot)
    }

    func insert(
        _ photoBooths: [PhotoBooth],
        for tile: MapTile,
        metadata: PhotoBoothCacheMetadata
    ) {
        let snapshot = PhotoBoothTileCacheSnapshot(photoBooths: photoBooths, metadata: metadata)
        let entry = Entry(snapshot: snapshot)
        storage.setObject(entry, forKey: Key(tile: tile), cost: max(photoBooths.count, 1))
    }

    func removeAll() {
        storage.removeAllObjects()
    }
}
