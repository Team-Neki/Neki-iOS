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


// MARK: - ArchiveAnalyticsEvent + Album Selection

extension ArchiveAnalyticsEvent {
    /// 여러 장을 골라 앨범 선택을 마쳤을 때 보낼 이벤트입니다.
    ///
    /// 이동은 `photo_move`만, 복사는 `album_add_from_multi`와 `photo_copy`를 함께 보냅니다.
    /// 사진 상세에서 한 장을 추가할 때는 `album_add_from_detail`만 보내므로 여기서 다루지 않습니다.
    static func multiPhotoSelectionEvents(
        for purpose: PhotoSelectionPurpose,
        photoCount: Int,
        albumCount: Int
    ) -> [ArchiveAnalyticsEvent] {
        switch purpose {
        case .move: return [.photoMove]
        case .duplicate: return [.albumAddFromMulti(photoCount: photoCount, albumCount: albumCount), .photoCopy]
        case .upload: return []
        }
    }
}


// MARK: - ArchiveAnalyticsEvent + Equatable

extension ArchiveAnalyticsEvent: Equatable {}
