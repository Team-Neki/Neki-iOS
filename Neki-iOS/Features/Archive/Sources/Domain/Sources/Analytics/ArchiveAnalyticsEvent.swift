//
//  ArchiveAnalyticsEvent.swift
//  Neki-iOS
//
//  Created by OneTen on 4/19/26.
//

import Foundation

public enum ArchiveAnalyticsEvent: AnalyticsEvent {
    case archivingView
    case photoUpload(method: String, count: Int)
    case albumCreate
    case albumAddFromDetail(albumCount: Int)
    case albumAddFromMulti(photoCount: Int, albumCount: Int)
    case photoAddToAlbum(photoCount: Int, albumCount: Int)
    case photoMove
    case photoCopy
    case photoDetailView
    case photoMemoCreate
    
    public var name: AnalyticsEventName {
        switch self {
        case .archivingView: return .archivingView
        case .photoUpload: return .photoUpload
        case .albumCreate: return .albumCreate
        case .albumAddFromDetail: return .albumAddFromDetail
        case .albumAddFromMulti: return .albumAddFromMulti
        case .photoAddToAlbum: return .photoAddToAlbum
        case .photoMove: return .photoMove
        case .photoCopy: return .photoCopy
        case .photoDetailView: return .photoDetailView
        case .photoMemoCreate: return .photoMemoCreate
        }
    }
    
    public var parameters: [AnalyticsParameterKey: Any]? {
        switch self {
        case let .photoUpload(method, count):
            return [.method: method, .count: count]
            
        case let .albumAddFromDetail(albumCount):
            return [.albumCount: albumCount]
            
        case let .albumAddFromMulti(photoCount, albumCount):
            return [.photoCount: photoCount, .albumCount: albumCount]
            
        case let .photoAddToAlbum(photoCount, albumCount):
            return [.photoCount: photoCount, .albumCount: albumCount]
            
        default:
            return nil
        }
    }
}
