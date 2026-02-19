//
//  PhotoBoothNameFormatter.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/19/26.
//

import Foundation

public struct PhotoBoothNameFormatter {
    private let multilineDisplayName: [String: String] = [
        "포토그레이": "포토\n그레이",
        "포토시그니처": "포토\n시그니처",
        "플랜비스튜디오": "플랜비\n스튜디오"
    ]
    
    public func format(brand: PhotoBoothBrand) -> String { multilineDisplayName[brand.name] ?? brand.name }
}
