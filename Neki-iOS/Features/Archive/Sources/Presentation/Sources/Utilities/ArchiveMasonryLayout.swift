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
        photos.enumerated().forEach { index, photo in
            columns[index % columnCount].append(ArchivePhotoGridItem(id: photo.id))
        }
        return columns
    }
}

struct ArchivePhotoGridItem: Equatable, Identifiable, Sendable {
    let id: Int
}
