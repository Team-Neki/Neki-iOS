//
//  SharedImageRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 3/20/26.
//

import Foundation

public protocol SharedImageRepository: Sendable {
    func fetchSharedImageURLs(appGroupID: String) async throws -> [URL]
    func fetchSharedImages(appGroupID: String) async throws -> [ImageUploadEntity]
    func clearSharedImages(appGroupID: String) async throws
}
