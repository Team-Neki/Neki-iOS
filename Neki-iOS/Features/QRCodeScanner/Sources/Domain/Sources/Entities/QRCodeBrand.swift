//
//  QRCodeBrand.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation


// MARK: - PhotoBoothBrand + URLHosts

public enum QRCodeBrand: CustomStringConvertible, Sendable {
    case life4cut
    case photoism
    case photogray
    case photosignature
    case planBStudio
    case harufilm
    
    var hostKeywords: [String] {
        switch self {
        case .life4cut: ["life4cut.net", "api.life4cut.net", "life-4cut.net"]
        case .photoism: ["seobuk.kr"]
        case .photogray: ["aprd.io", "pgshort.aprd.io"]
        case .photosignature: ["photoqr3.kr"]
        case .planBStudio: []
        case .harufilm: ["haru4.mx2.co.kr", "haru3.mx2.co.kr", "haru2.mx2.co.kr", "haru1.mx2.co.kr", "haru.mx2.co.kr"]
        }
    }
    
    public var description: String {
        switch self {
        case .life4cut: return "인생네컷"
        case .photoism: return "포토이즘"
        case .photogray: return "포토그레이"
        case .photosignature: return "포토시그니처"
        case .planBStudio: return "플랜비스튜디오"
        case .harufilm: return "하루필름"
        }
    }
}
