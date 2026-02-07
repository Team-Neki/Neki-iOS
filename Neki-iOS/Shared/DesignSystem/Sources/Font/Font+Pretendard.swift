//
//  Font+Pretendard.swift
//  Neki-iOS
//
//  Created by SwainYun on 12/22/25.
//

import SwiftUI

public enum FontStyle: CaseIterable {
    case title28Bold, title28SemiBold
    case title24Bold, title24SemiBold
    case title20Bold, title20SemiBold, title20Medium
    case title18Bold, title18SemiBold, title18Medium, title18Regular
    case body16SemiBold, body16Medium, body16Regular
    case body14SemiBold, body14Medium, body14Regular
    case caption12SemiBold, caption12Medium, caption12Regular
    case caption11SemiBold, caption11Medium
    
    var fontSize: CGFloat {
        switch self {
        case .title28Bold, .title28SemiBold: 28
        case .title24Bold, .title24SemiBold: 24
        case .title20Bold, .title20SemiBold, .title20Medium: 20
        case .title18Bold, .title18SemiBold, .title18Medium, .title18Regular: 18
        case .body16SemiBold, .body16Medium, .body16Regular: 16
        case .body14SemiBold, .body14Medium, .body14Regular: 14
        case .caption12SemiBold, .caption12Medium, .caption12Regular: 12
        case .caption11SemiBold, .caption11Medium: 11
        }
    }
    
    var textStyle: Font.TextStyle {
        switch self {
        case .title28Bold, .title28SemiBold, .title24Bold, .title24SemiBold, .title20Bold, .title20SemiBold, .title20Medium, .title18Bold, .title18SemiBold, .title18Medium, .title18Regular: .title
        case .body16SemiBold, .body16Medium, .body16Regular, .body14SemiBold, .body14Medium, .body14Regular: .body
        case .caption12SemiBold, .caption12Medium, .caption12Regular, .caption11SemiBold, .caption11Medium: .caption
        }
    }
    
    var lineHeight: CGFloat {
        switch self {
        case .title28Bold, .title28SemiBold: 40
        case .title24Bold, .title24SemiBold: 36
        case .title20Bold, .title20SemiBold, .title20Medium, .title18Bold, .title18SemiBold, .title18Medium, .title18Regular: 28
        case .body16SemiBold, .body16Medium, .body16Regular: 24
        case .body14SemiBold, .body14Medium, .body14Regular: 20
        case .caption12SemiBold, .caption12Medium, .caption12Regular, .caption11SemiBold, .caption11Medium: 16
        }
    }
    
    var letterSpacing: CGFloat { .zero }
    
    var fontName: String {
        switch self {
        case .title28Bold, .title24Bold, .title20Bold, .title18Bold: "Pretendard-Bold"
        case .title28SemiBold, .title24SemiBold, .title20SemiBold, .title18SemiBold, .body16SemiBold, .body14SemiBold, .caption12SemiBold, .caption11SemiBold: "Pretendard-SemiBold"
        case .title20Medium, .title18Medium, .body16Medium, .body14Medium, .caption12Medium, .caption11Medium: "Pretendard-Medium"
        case .title18Regular, .body16Regular, .body14Regular, .caption12Regular: "Pretendard-Regular"
        }
    }
}
