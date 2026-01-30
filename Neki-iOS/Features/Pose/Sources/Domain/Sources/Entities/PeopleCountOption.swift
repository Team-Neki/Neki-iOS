//
//  PeopleCountOption.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation

// TODO: 포즈 인원수 필터 옵션 케이스 변경 예정
public enum PeopleCountOption: Int, CaseIterable {
    case solo = 1, duo, trio, quartet, overQuartet
    
    var displayName: String {
        guard case .overQuartet = self else { return "\(self.rawValue)인" }
        return "\(self.rawValue)인 이상"
    }
}
