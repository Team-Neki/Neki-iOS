import Foundation

public enum ArchiveAnalyticsEvent: AnalyticsEvent {
    /// 아카이브 첫 화면이 보일 때마다 기록합니다. 탭을 옮겨 오거나 앨범·사진 화면, QR·알림 목록에서 돌아올 때도 포함합니다.
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


// MARK: - ArchiveAnalyticsEvent + Equatable

extension ArchiveAnalyticsEvent: Equatable {}
