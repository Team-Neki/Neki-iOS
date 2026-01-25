//
//  PhotoBoothBrand+URLHosts.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/6/26.
//

import Foundation


// MARK: - PhotoBoothBrand + URLHosts

extension PhotoBoothBrand {
    var hostKeywords: [String] {
        switch self {
        case .life4cut: ["life4cut.net", "api.life4cut.net", "life-4cut.net"]
        case .photoism: ["seobuk.kr"]
        case .photogray: ["aprd.io", "pgshort.aprd.io"]
        case .photosignature: ["photoqr3.kr"]
        case .planBStudio: []
        case .harufilm: ["haru4.mx2.co.kr", "haru3.mx2.co.kr", "haru2.mx2.co.kr", "haru1.mx2.co.kr", "haru.mx2.co.kr", "harufilm"]
        }
    }
}
