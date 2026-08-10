//
//  AppDiagnosticsRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/8/26.
//

public protocol AppDiagnosticsRepository {
    func fetch(
        authTokens: AuthTokens?,
        apnsTokenStatus: AppDiagnostics.TokenStatus,
        fcmTokenStatus: AppDiagnostics.TokenStatus
    ) async -> AppDiagnostics
}
