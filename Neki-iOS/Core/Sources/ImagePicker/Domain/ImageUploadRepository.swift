//
//  ImageUploadRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import Foundation

public protocol ImageUploadRepository {
    func upload(items: [ImageUploadEntity], mediaType: ImageMediaType) async throws -> [Int]
}
