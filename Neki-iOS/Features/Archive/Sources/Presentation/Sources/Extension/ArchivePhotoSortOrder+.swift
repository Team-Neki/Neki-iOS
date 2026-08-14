//
//  ArchivePhotoSortOrder+.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/14/26.
//

extension ArchivePhotoSortOrder {
    var displayName: String {
        switch self {
        case .ascending: "오래된순"
        case .descending: "최신순"
        }
    }
}
