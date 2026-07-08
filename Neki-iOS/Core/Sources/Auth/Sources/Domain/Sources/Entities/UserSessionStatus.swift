//
//  UserSessionStatus.swift
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
