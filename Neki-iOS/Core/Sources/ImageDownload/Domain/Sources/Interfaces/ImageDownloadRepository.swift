//
//  ImageDownloadRepository.swift
//  Neki-iOS
//
//  Created by Codex on 7/8/26.
//

import Foundation

protocol ImageDownloadRepository {
    func downloadImages(urls: [URL]) async throws -> Int
}
