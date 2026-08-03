import Foundation

public enum ArchiveAnalyticsEvent: AnalyticsEvent {
    case archivingView
    case photoUpload(method: PhotoUploadMethod, count: Int)
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
    
    public var parameters: [AnalyticsParameterKey: AnalyticsParameterValue]? {
        switch self {
        case let .photoUpload(method, count):
            let methodString = (method == .qr) ? "qr" : "gallery"
            return [.method: .string(methodString), .count: .integer(count)]
            
        case let .albumAddFromDetail(albumCount):
            return [.albumCount: .integer(albumCount)]
            
        case let .albumAddFromMulti(photoCount, albumCount):
            return [.photoCount: .integer(photoCount), .albumCount: .integer(albumCount)]
            
        case let .photoAddToAlbum(photoCount, albumCount):
            return [.photoCount: .integer(photoCount), .albumCount: .integer(albumCount)]
            
        default:
            return nil
        }
    }
}
