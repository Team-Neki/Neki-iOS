//
//  ArchiveImageView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import Kingfisher

struct ArchiveImageView: View {
    
    //MARK: - Properties

    let item: ArchiveImageItem
    
    //MARK: - Main Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KFImage(item.imageURL)
                .resizable()
                .placeholder {
                    placeholderView
                }
                .retry(maxCount: 3, interval: .seconds(5))
                .onFailure { error in
                    print("이미지 로드 실패: \(error)")
                }
                .aspectRatio(contentMode: .fit)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .clipped()
    }
}


//MARK: - Sub View

extension ArchiveImageView {
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.gray100)
            .frame(height: 180)
            .overlay {
                ProgressView()
            }
    }
}
