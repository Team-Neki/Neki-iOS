//
//  ArchiveMasonryLayout.swift
//  Neki-iOS
//
//  Created by Codex on 7/3/26.
//

enum ArchiveMasonryLayout {
    static func columns(
        for photos: some Collection<PhotoEntity>,
        columnCount: Int = 2
    ) -> [[ArchivePhotoGridItem]] {
        let columnCount = max(1, columnCount)
        var columns = Array(repeating: [ArchivePhotoGridItem](), count: columnCount)
        var columnHeights = Array(repeating: Double.zero, count: columnCount)

        photos.forEach { photo in
            let columnIndex = columnHeights
                .enumerated()
                .min(by: { $0.element < $1.element })?
                .offset ?? .zero
            let item = ArchivePhotoGridItem(id: photo.id, estimatedHeight: estimatedHeight(for: photo))
            columns[columnIndex].append(item)
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

struct ArchivePhotoGridItem: Equatable, Identifiable, Sendable {
    let id: Int
    let estimatedHeight: Double
}
