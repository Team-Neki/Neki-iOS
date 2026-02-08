//
//  ImageDownsamplingProcessor.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import ImageIO
import UniformTypeIdentifiers
import os

public struct ImageDownsamplingProcessor: Sendable {
    public struct ProcessedImage: Sendable {
        /// JPEG Data
        public let data: Data
    }
    
    /// 목표 해상도: 4096px (4K)
    /// Presigned URL 최대 용량: 5GB
    private static let maxDimensionInPixels: CGFloat = 4096
    
    private init() {}
    
    nonisolated public static func process(data: Data) async -> ProcessedImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            Logger.domain.error("❌ ImageDownsamplingProcessor: 이미지 소스 생성 실패")
            return nil
        }
        
        guard CGImageSourceGetCount(imageSource) > .zero else {
            Logger.domain.error("❌ ImageDownsamplingProcessor: 이미지 소스 내 이미지 개수 0")
            return nil
        }
        
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, .zero, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? CGFloat ?? .zero
        let height = properties?[kCGImagePropertyPixelHeight] as? CGFloat ?? .zero
        let maxSide = max(width, height)
        
        let targetPixelSize: Int = maxSide > .zero ? Int((maxSide > maxDimensionInPixels) ? maxDimensionInPixels : maxSide) : Int(maxDimensionInPixels)
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: kCFBooleanTrue as Any,
            kCGImageSourceShouldCacheImmediately: kCFBooleanTrue as Any,
            kCGImageSourceCreateThumbnailWithTransform: kCFBooleanTrue as Any,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize as CFNumber
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, .zero, options as CFDictionary) else {
            Logger.domain.error("❌ ImageDownsamplingProcessor: 썸네일 생성 실패")
            return nil
        }
        let mutableData = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let webPOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8 // 80% 압축
        ]
        
        CGImageDestinationAddImage(destination, cgImage, webPOptions as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return ProcessedImage(data: mutableData as Data)
    }
}
