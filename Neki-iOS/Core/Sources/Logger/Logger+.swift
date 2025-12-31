//
//  Logger+.swift
//  Neki-iOS
//
//  Created by OneTen on 12/31/25.
//

import Foundation
import os

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "Neki"
    
    // MARK: - 로그를 성격별로 나누어 사용합니다
    
    /// 네트워크 통신 관련
    static let network = Logger(subsystem: subsystem, category: "Network")
    
    /// 데이터 관련
    static let data = Logger(subsystem: subsystem, category: "Data")
    
    /// Presentation 관련
    static let presentation = Logger(subsystem: subsystem, category: "Presentation")
    
    /// 도메인 관련
    static let domain = Logger(subsystem: subsystem, category: "Domain")
}
