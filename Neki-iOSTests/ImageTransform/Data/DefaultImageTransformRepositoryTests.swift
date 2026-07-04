//
//  DefaultImageTransformRepositoryTests.swift
//  Neki-iOSTests
//
//  Created by OneTen on 3/15/26.
//

import Testing
import Foundation
import CoreGraphics
@testable import Neki_iOS

@Suite(.serialized)
struct DefaultImageTransformRepositoryTests {
    
    @Test("시나리오 1: 정상적인 이미지를 넣으면 변환된 CGImage를 반환한다")
    func transform_whenValidImage_returnsCGImage() async throws {
        // given
        let repository = DefaultImageTransformRepository()
        let inputImage = try createValidCGImage()
        
        // when
        let outputImage = try await repository.transform(image: inputImage)

        // then
        #expect(outputImage.width > 0)
        #expect(outputImage.height > 0)
    }
    
    @Test("시나리오 2: 같은 Repository의 후속 요청에서도 변환 결과를 반환한다")
    func transform_whenRequestedAgain_reusesLoadedModel() async throws {
        // given
        let repository = DefaultImageTransformRepository()
        let inputImage = try createValidCGImage()
        
        // when
        _ = try await repository.transform(image: inputImage)
        let outputImage = try await repository.transform(image: inputImage)

        // then
        #expect(outputImage.width > 0)
        #expect(outputImage.height > 0)
    }
}


// MARK: - Helper Methods

private extension DefaultImageTransformRepositoryTests {
    func createValidCGImage() throws -> CGImage {
        let width = 100
        let height = 100
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        ) else {
            struct ContextError: Error {}
            throw ContextError()
        }
        
        context.setFillColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let image = context.makeImage() else {
            struct ImageError: Error {}
            throw ImageError()
        }
        return image
    }
}
