//
//  AppVersionRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 2/17/26.
//

import Foundation

protocol AppVersionRepository: Sendable {
    func fetchVersionInfo() async throws -> (minimumVersion: AppVersion, latestVersion: AppVersion)
}
