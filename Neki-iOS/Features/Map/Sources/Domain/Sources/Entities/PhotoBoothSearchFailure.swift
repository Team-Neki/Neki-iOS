//
//  PhotoBoothSearchFailure.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/28/26.
//

/// 검색 요청이 실패한 원인입니다.
///
/// 어떤 전송 오류가 어느 원인에 해당하는지는 전송 계층을 아는 Data 레이어에서 판정합니다.
public enum PhotoBoothSearchFailure: Error, Equatable, Sendable {
    /// 네트워크에 연결할 수 없어 실패했습니다.
    case network
    /// 그 밖의 이유로 실패했습니다.
    case unknown
}
