//
//  UIImage+.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import SwiftUI

public extension UIImage {
    func processedImage() -> ImageUploadEntity? {
        
        var finalData: Data?
        var format: ImageFileFormat = .jpeg
        
        if let pngData = self.pngData() {
            finalData = pngData
            format = .png
        } else {
            finalData = self.jpegData(compressionQuality: 1.0)  // 아직 별도 압축 없음
            format = .jpeg
        }
        
        guard let data = finalData else { return nil }
        
        return ImageUploadEntity(data: data, format: format)
    }
}
