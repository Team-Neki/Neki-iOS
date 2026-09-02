//
//  PhotoBoothRegionCache.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/30/26.
//

import Foundation

/// 확장된 지도 영역별 포토부스 조회 결과와 캐시 메타데이터를 보관합니다.
///
/// 조회 시 주입된 신선도 정책을 적용하여 데이터를 구분하며,
/// 데이터 갱신과 fallback 사용 여부는 Repository급에서 결정합니다.
final class PhotoBoothRegionCache {
    private final class Key: NSObject {
        let bounds: GeographicBoundingBox

        init(bounds: GeographicBoundingBox) {
            self.bounds = bounds
        }

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(bounds.minLatitude)
            hasher.combine(bounds.minLongitude)
            hasher.combine(bounds.maxLatitude)
            hasher.combine(bounds.maxLongitude)
            return hasher.finalize()
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Key else { return false }
            return bounds == other.bounds
        }
    }

    private final class Entry {
        let snapshot: PhotoBoothRegionCacheSnapshot

        init(snapshot: PhotoBoothRegionCacheSnapshot) {
            self.snapshot = snapshot
        }
    }

    private let storage: NSCache<Key, Entry>
    private let freshnessPolicy: any PhotoBoothCacheFreshnessPolicy

    init(configuration: PhotoBoothCacheConfiguration) {
        let storage = NSCache<Key, Entry>()
        storage.countLimit = configuration.maximumRegionCount
        storage.totalCostLimit = configuration.maximumPhotoBoothCount
        self.storage = storage
        freshnessPolicy = configuration.freshnessPolicy
    }

    func lookup(bounds: GeographicBoundingBox, now: Date) -> PhotoBoothRegionCacheLookup {
        guard let entry = storage.object(forKey: Key(bounds: bounds)) else { return .missing }
        guard freshnessPolicy.isFresh(metadata: entry.snapshot.metadata, now: now) else { return .stale(entry.snapshot) }
        return .fresh(entry.snapshot)
    }

    func insert(
        _ photoBooths: [PhotoBooth],
        for bounds: GeographicBoundingBox,
        metadata: PhotoBoothCacheMetadata
    ) {
        let snapshot = PhotoBoothRegionCacheSnapshot(photoBooths: photoBooths, metadata: metadata)
        storage.setObject(
            Entry(snapshot: snapshot),
            forKey: Key(bounds: bounds),
            cost: max(photoBooths.count, 1)
        )
    }

    func removeAll() {
        storage.removeAllObjects()
    }
}
