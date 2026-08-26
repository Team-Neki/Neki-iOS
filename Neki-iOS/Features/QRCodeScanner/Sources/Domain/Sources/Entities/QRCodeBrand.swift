//
//  QRCodeBrand.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation


// MARK: - QRCodeBrand + URL Hosts

public enum QRCodeBrand: CustomStringConvertible, Sendable {
    case life4cut
    case photoism
    case photogray
    case photosignature
    case photosignatureCode
    case monoMansion
    case planBStudio
    case harufilm
    case auraPic
    case theSayCheese

    var hostKeywords: [String] {
        switch self {
        case .life4cut: ["life4cut.net", "api.life4cut.net", "life-4cut.net"]
        case .photoism: ["seobuk.kr"]
        case .photogray: ["aprd.io", "pgshort.aprd.io"]
        case .photosignature: ["photoqr3.kr", "photosignature-viewer.web.app"]
        case .photosignatureCode: ["imagenetworks.web.app"]
        case .monoMansion: ["qr.mono-mansion.com"]
        case .planBStudio: []
        case .harufilm: ["haru4.mx2.co.kr", "haru3.mx2.co.kr", "haru2.mx2.co.kr", "haru1.mx2.co.kr", "haru.mx2.co.kr"]
        case .auraPic: ["pos.aurapic.co.kr", "aurapic.co.kr"]
        case .theSayCheese: ["thesaycheese.co.kr"]
        }
    }
    
    public var description: String {
        switch self {
        case .life4cut: return "인생네컷"
        case .photoism: return "포토이즘"
        case .photogray: return "포토그레이"
        case .photosignature: return "포토시그니처"
        case .photosignatureCode: return "포토시그니처 CODE"
        case .monoMansion: return "모노맨션"
        case .planBStudio: return "플랜비스튜디오"
        case .harufilm: return "하루필름"
        case .auraPic: return "아우라픽"
        case .theSayCheese: return "더세이치즈"
        }
    }
}
