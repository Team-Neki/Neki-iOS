//
//  ImageTransformRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 3/14/26.
//

import Foundation

public protocol ImageTransformRepository: Sendable {
    func transform(data: Data, model: ImageTransformModel) async throws -> Data
}
