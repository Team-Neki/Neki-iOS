//
//  PhotoBoothBrand.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation

/// 포토부스 브랜드의 종류입니다.
public enum PhotoBoothBrand: CaseIterable, Sendable {
    case life4cut
    case photoism
    case photogray
    case photosignature
    case planBStudio
    case monomansion
    case theFilm
    case insphoto
    case unknown
    
    public var displayName: String {
        switch self {
        case .life4cut: "인생네컷"
        case .photoism: "포토이즘"
        case .photogray: "포토 그레이"
        case .photosignature: "포토 시그니처"
        case .planBStudio: "플랜 비 스튜디오"
        case .monomansion: "모노맨션"
        case .theFilm: "더필름"
        case .insphoto: "인스포토"
        case .unknown: "비지원 브랜드"
        }
    }
}
