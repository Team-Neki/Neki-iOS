//
//  ImageDownsamplingProcessor.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import ImageIO
import UniformTypeIdentifiers

public struct ImageDownsamplingProcessor {
    public struct ProcessedImage {
        /// WebP Data
        public let data: Data
    }
    
    /// 목표 해상도: 4096px (4K)
    /// Presigned URL 최대 용량: 5GB
    private static let maxDimensionInPixels: CGFloat = 4096
    
    nonisolated public static func process(data: Data) async -> ProcessedImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, .zero, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? CGFloat ?? .zero
        let height = properties?[kCGImagePropertyPixelHeight] as? CGFloat ?? .zero
        let maxSide = max(width, height)
        let shouldResize = maxSide > maxDimensionInPixels
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: shouldResize ? maxDimensionInPixels : maxSide
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, .zero, options as CFDictionary) else { return nil }
        let mutableData = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.webP.identifier as CFString, 1, nil) else { return nil }
        let webPOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8 // 80% 압축
        ]
        
        CGImageDestinationAddImage(destination, cgImage, webPOptions as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return ProcessedImage(data: mutableData as Data)
    }
}
