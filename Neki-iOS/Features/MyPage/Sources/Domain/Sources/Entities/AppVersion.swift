//
//  AppVersion.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/17/26.
//

import Foundation

struct AppVersion: Sendable {
    let value: String
    
    init(value: String) { self.value = value }
    init(major: Int, minor: Int, revision: Int) { self.value = "\(major).\(minor).\(revision)" }
}


// MARK: - AppVersion + Comparable & Equatable

extension AppVersion: Comparable, Equatable {
    private var versionComponents: [Int] { value.split(separator: ".").compactMap { Int($0) } }
    
    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.versionComponents == rhs.versionComponents
    }
    
    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let lhsComponents = lhs.versionComponents
        let rhsComponents = rhs.versionComponents
        let maxLength = max(lhsComponents.count, rhsComponents.count)
        
        for i in 0..<maxLength {
            let lhsValue = i < lhsComponents.count ? lhsComponents[i] : 0
            let rhsValue = i < rhsComponents.count ? rhsComponents[i] : 0
            
            guard lhsValue != rhsValue else { continue }
            return lhsValue < rhsValue
        }
        
        return false
    }
}

/// 업데이트가 요구되는 상태를 의미합니다.
enum AppUpdateStatus: Equatable, Sendable {
    /// 업데이트 필요
    case mustUpdate
    /// 업데이트 권장
    case optionalUpdate
    /// 업데이트 불필요(최신)
    case upToDate
}
