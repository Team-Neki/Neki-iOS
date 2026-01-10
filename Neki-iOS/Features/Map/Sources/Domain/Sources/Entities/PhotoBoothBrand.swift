//
//  PhotoBoothBrand.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/29/25.
//

import Foundation
import DeveloperToolsSupport

/// 포토부스 브랜드의 종류입니다.
public enum PhotoBoothBrand: CaseIterable, Sendable {
    case life4cut
    case photoism
    case photogray
    case photosignature
    case harufilm
    case planBStudio
    
    public var displayName: String {
        switch self {
        case .life4cut: "인생네컷"
        case .photoism: "포토이즘"
        case .photogray: "포토 그레이"
        case .photosignature: "포토 시그니처"
        case .harufilm: "하루필름"
        case .planBStudio: "플랜비 스튜디오"
        }
    }
    
    public var logoImageResource: ImageResource {
        switch self {
        case .life4cut: return .imgLife4CutOriginal
        case .photoism: return .imgPhotoismOriginal
        case .photogray: return .imgPhotograyOriginal
        case .photosignature: return .imgPhotosignatureOriginal
        case .harufilm: return .imgHarufilmOriginal
        case .planBStudio: return .imgPlanbstudioOriginal
        }
    }
}
