//
//  QRCodeBrand.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation

public enum QRCodeBrand: CustomStringConvertible, Sendable {
    case life4cut
    case photoism
    case photogray
    case photosignature
    case monoMansion
    case planBStudio
    case harufilm
    case auraPic
    
    public var description: String {
        switch self {
        case .life4cut: return "인생네컷"
        case .photoism: return "포토이즘"
        case .photogray: return "포토그레이"
        case .photosignature: return "포토시그니처"
        case .monoMansion: return "모노맨션"
        case .planBStudio: return "플랜비스튜디오"
        case .harufilm: return "하루필름"
        case .auraPic: return "아우라픽"
        }
    }
}
