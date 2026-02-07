//
//  FeedImageView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import Kingfisher
import os

struct FeedImageView: View {
    
    //MARK: - Properties
    
    let item: Pose
    
    let gradientColor: LinearGradient = LinearGradient(
        colors: [
            .black.opacity(0),
            .black
        ],
        startPoint: UnitPoint(x: 0.54, y: 0.42),
        endPoint: UnitPoint(x: 0.54, y: 0.05)
    )
    
    //MARK: - Main Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KFImage(item.imageURL)
                .resizable()
                .fade(duration: 0.25)
                .retry(maxCount: 3, interval: .seconds(5))
                .onFailure { error in
                    Logger.presentation.error("이미지 로드 실패: \(error)")
                    Logger.presentation.error("실패한 이미지 id: \(item.id)")
                }
                .cancelOnDisappear(true)
                .aspectRatio(contentMode: .fit)
        }
        .overlay(content: {
            Color.black.opacity(0.04)
        })
        .overlay(content: {
            gradientColor.opacity(0.2)
        })
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .clipped()
    }
}
