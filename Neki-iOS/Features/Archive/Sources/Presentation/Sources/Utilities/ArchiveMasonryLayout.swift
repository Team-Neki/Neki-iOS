//
//  ArchiveMasonryLayout.swift
//  Neki-iOS
//
//  Created by Codex on 7/3/26.
//

enum ArchiveMasonryLayout {
    struct CacheKey: Equatable, Sendable {
        let columnCount: Int
        let items: [Item]

        init(photos: some Collection<PhotoEntity>, columnCount: Int) {
            self.columnCount = max(1, columnCount)
            self.items = photos.map {
                Item(id: $0.id, estimatedHeight: ArchiveMasonryLayout.estimatedHeight(for: $0))
            }
        }
    }

    static func columns(
        for photos: some Collection<PhotoEntity>,
        columnCount: Int = 2
    ) -> [[ArchivePhotoGridItem]] {
        let key = CacheKey(photos: photos, columnCount: columnCount)
        return columns(for: key)
    }

    static func columns(
        for photos: some Collection<PhotoEntity>,
        columnCount: Int = 2,
        cachedKey: CacheKey?,
        cachedColumns: [[ArchivePhotoGridItem]]
    ) -> (columns: [[ArchivePhotoGridItem]], key: CacheKey) {
        let key = CacheKey(photos: photos, columnCount: columnCount)
        guard cachedKey != key else { return (cachedColumns, key) }
        return (columns(for: key), key)
    }

    private static func columns(for key: CacheKey) -> [[ArchivePhotoGridItem]] {
        var columns: [[ArchivePhotoGridItem]] = MasonryColumnBuilder.emptyColumns(count: key.columnCount, itemCount: key.items.count)
        var columnHeights = Array(repeating: Double.zero, count: key.columnCount)

        key.items.forEach { item in
            let columnIndex = columnHeights
                .enumerated()
                .min(by: { $0.element < $1.element })?
                .offset ?? .zero
            columns[columnIndex].append(.init(id: item.id, estimatedHeight: item.estimatedHeight))
            columnHeights[columnIndex] += item.estimatedHeight
        }
        return columns
    }

    private static func estimatedHeight(for photo: PhotoEntity) -> Double {
        guard let width = photo.width, let height = photo.height else { return 1 }
        guard width > .zero, height > .zero else { return 1 }
        return Double(height) / Double(width)
    }

}

extension ArchiveMasonryLayout.CacheKey {
    struct Item: Equatable, Sendable {
        let id: Int
        let estimatedHeight: Double
    }
}

struct ArchivePhotoGridItem: Equatable, Identifiable, Sendable {
    let id: Int
    let estimatedHeight: Double
}
