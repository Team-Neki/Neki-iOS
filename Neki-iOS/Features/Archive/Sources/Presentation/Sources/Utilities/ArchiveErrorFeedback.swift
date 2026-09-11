//
//  ArchiveErrorFeedback.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

/// 전역 로그인 안내로 처리되는 인증 실패와 취소된 작업을 개별 오류 안내에서 제외합니다.
/// 로딩 해제와 낙관적 변경 롤백은 각 Feature가 먼저 수행합니다.
enum ArchiveErrorFeedback {
    static func shouldPresent(for error: Error) -> Bool {
        guard error is CancellationError == false else { return false }
        guard error as? ArchiveRequestError != .authenticationRequired else { return false }
        guard error as? UploadError != .authenticationRequired else { return false }
        return true
    }
}
