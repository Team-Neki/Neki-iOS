//
//  Data+.swift
//  Neki-iOS
//
//  Created by OneTen on 1/23/26.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

extension Data {
    /// 데이터의 매직넘버(MagicNumber)를 확인하여 이미지 포맷을 판별합니다.
    var detectedImageFormat: ImageFileFormat {
        // 데이터가 너무 짧으면 기본값(JPEG) 반환
        guard self.count > 12 else { return .jpeg }
        
        let header = self.prefix(12)
        let firstByte = header[0]
        
        // PNG 확인 (0x89로 시작)
        if firstByte == 0x89 {
            return .png
        }
        
        // WebP 확인
        // WebP 파일 구조:
        // Offset 0-3: "RIFF" (0x52, 0x49, 0x46, 0x46)
        // Offset 8-11: "WEBP" (0x57, 0x45, 0x42, 0x50)
        if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 && // "RIFF"
            header[8] == 0x57 && header[9] == 0x45 && header[10] == 0x42 && header[11] == 0x50 { // "WEBP"
            return .webp
        }
        
        // 나머지는 JPEG로
        return .jpeg
    }
    
    var detectedContentType: UTType? {
        guard let source = CGImageSourceCreateWithData(self as CFData, nil),
              let typeIdentifier = CGImageSourceGetType(source)
        else { return nil }
        return UTType(typeIdentifier as String)
    }
    
    var imageDimensions: (width: Int, height: Int)? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        
        guard let source = CGImageSourceCreateWithData(self as CFData, options as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options as CFDictionary) as? [CFString: Any] else {
            return nil
        }
        
        let width = properties[kCGImagePropertyPixelWidth] as? Int
        let height = properties[kCGImagePropertyPixelHeight] as? Int
        
        if let w = width, let h = height {
            return (w, h)
        }
        
        return nil
    }
}
