//
//  UsesSessionStatus.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/2/26.
//

import Foundation

public enum UserSessionStatus: Equatable, Codable {
    case signedIn(User)
    case signedOut
    case expired
}

extension UserSessionStatus {
    public static func updateStatus(_ status: Self, encoder: JSONEncoder = JSONEncoder()) {
        guard let data = try? encoder.encode(status) else { return }
        UserDefaults.standard.set(data, forKey: AppStorageKey.userSessionStatus)
    }
}
