//
//  AuthLoginResult.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/3/26.
//

public enum RegistrationStatus: Sendable, Equatable {
    case newlyRegistered
    case existingAccount
}

public struct AuthLoginResult: Sendable {
    public let user: User
    public let registrationStatus: RegistrationStatus

    public init(user: User, registrationStatus: RegistrationStatus) {
        self.user = user
        self.registrationStatus = registrationStatus
    }
}
