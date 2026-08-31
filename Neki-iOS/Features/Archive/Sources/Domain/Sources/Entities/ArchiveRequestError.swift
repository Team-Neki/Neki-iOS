//
//  ArchiveRequestError.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/31/26.
//

/// 아카이빙 작업을 계속하기 위해 인증 복구가 필요한 경우입니다.
enum ArchiveRequestError: Error, Equatable, Sendable {
    case authenticationRequired
}
