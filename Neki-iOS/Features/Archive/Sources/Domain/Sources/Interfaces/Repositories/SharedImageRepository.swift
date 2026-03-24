//
//  SharedImageRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 3/20/26.
//

import Foundation

public protocol SharedImageRepository {
    func fetchSharedImageURLs(appGroupID: String) async throws -> [URL]
    func clearSharedImages(appGroupID: String) async throws
}
