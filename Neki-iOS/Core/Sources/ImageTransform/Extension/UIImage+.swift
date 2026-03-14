//
//  UIImage+.swift
//  Neki-iOS
//
//  Created by OneTen on 3/13/26.
//

import UIKit

extension UIImage {
    
    /// 현재 사용하는 MLModel의 input, output image 요구조건이 512x512 사이즈입니다. 머신러닝에는 보통 정사각형 이미지를 사용한다고 합니다.
    /// 즉, 1:1 비율에 맞지 않는 이미지를 선택할 경우, 사진이 찌그러지거나 아니면 1:1 비율에 맞춰 크롭해야 하는 문제사항이 있습니다
    /// 따라서 1:1 비율에 해당하지 않는 이미지일 경우 비율이 부족한 공간(가로 혹은 세로)을 임의로 채우는 방식을 채택했습니다.
    /// 프로세스는 아래와 같습니다.
    /// 1. 비율을 기억하고 512x512 정사각형으로 포장
    /// 2. 포장된 512x512 이미지 전체를 변환
    /// 3. 변환된 이미지를 기억해둔 원본 비율에 맞춰 crop
    /// 추후 다른 모델을 추가하게 될 경우, 요구되는 비율이 다를 수 있기에(1024x1024 등) targetSize를 입력받을 수 있도록 구현했습니다.
    func prepareSquareForCoreML(targetSize: CGFloat = 512) -> UIImage? {
        let size = CGSize(width: targetSize, height: targetSize)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        
        let imgRatio = self.size.width / self.size.height
        var drawRect: CGRect = .zero
        
        if imgRatio > 1.0 { // 가로가 긴 사진
            let h = targetSize / imgRatio
            drawRect = CGRect(x: 0, y: (targetSize - h) / 2.0, width: targetSize, height: h)
        } else { // 세로가 긴 사진
            let w = targetSize * imgRatio
            drawRect = CGRect(x: (targetSize - w) / 2.0, y: 0, width: w, height: targetSize)
        }
        
        self.draw(in: drawRect)
        let preparedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return preparedImage
    }
    
    func cropToOriginalRatio(originalRatio: CGFloat) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        // 모델이 뱉어낸 이미지 픽셀 사이즈
        let outputWidth = CGFloat(cgImage.width)
        let outputHeight = CGFloat(cgImage.height)
        
        var cropRect: CGRect = .zero
        
        if originalRatio > 1.0 { // 가로가 긴 원본
            let h = outputWidth / originalRatio
            cropRect = CGRect(x: 0, y: (outputHeight - h) / 2.0, width: outputWidth, height: h)
        } else { // 세로가 긴 원본
            let w = outputHeight * originalRatio
            cropRect = CGRect(x: (outputWidth - w) / 2.0, y: 0, width: w, height: outputHeight)
        }
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: croppedCGImage)
    }
}

