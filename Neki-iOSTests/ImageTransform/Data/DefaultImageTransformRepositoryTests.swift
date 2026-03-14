//
//  DefaultImageTransformRepositoryTests.swift
//  Neki-iOSTests
//
//  Created by OneTen on 3/15/26.
//

import Testing
import Foundation
import CoreGraphics
import UniformTypeIdentifiers
import ImageIO
@testable import Neki_iOS

struct DefaultImageTransformRepositoryTests {
    
    @Test("시나리오 1: 정상적인 이미지 데이터를 넣으면 변환된 PNG 데이터를 반환한다")
    func transform_whenValidData_returnsPNGData() async throws {
        // given
        let repository = DefaultImageTransformRepository()
        let inputData = try createValidPNGData()
        
        // when
        let outputData = try await repository.transform(data: inputData)
        let imageSource = CGImageSourceCreateWithData(outputData as CFData, nil)

        // then
        #expect(!outputData.isEmpty, "변환된 이미지 데이터가 비어있으면 안 됩니다.")
        #expect(imageSource != nil, "결과물이 정상적인 이미지 소스로 읽혀야 합니다.")
    }
    
    @Test("시나리오 2: 손상되거나 이미지가 아닌 데이터를 넣으면 에러를 던진다")
    func transform_whenInvalidData_throwsError() async {
        // given
        let repository = DefaultImageTransformRepository()
        let garbageData = Data([0x00, 0xFF, 0x11, 0x22, 0x33])
        
        // when & then
        await #expect(throws: Error.self) {
            _ = try await repository.transform(data: garbageData)
        }
    }
}


// MARK: - Helper Methods

private extension DefaultImageTransformRepositoryTests {
    func createValidPNGData() throws -> Data {
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
        
        guard let cgImage = context.makeImage() else {
            struct ImageError: Error {}
            throw ImageError()
        }
        
        let mutableData = CFDataCreateMutable(kCFAllocatorDefault, 0)!
        let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        
        return mutableData as Data
    }
}
