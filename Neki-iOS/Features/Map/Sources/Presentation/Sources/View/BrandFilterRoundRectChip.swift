//
//  BrandFilterRoundRectChip.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 9/8/26.
//

import SwiftUI
import Kingfisher

/// 브랜드 로고와 이름을 둥근 사각형 테두리로 감싼 필터 칩입니다.
///
/// 골라져 있으면 테두리와 이름이 primary 색으로 바뀝니다.
struct BrandFilterRoundRectChip: View {
    let brand: PhotoBoothBrand
    let isSelected: Bool
    let action: () -> Void

    private enum Constants {
        static let cornerRadius: CGFloat = 8
        static let borderWidth: CGFloat = 1
        static let logoSize: CGFloat = 24
        static let logoBorderWidth: CGFloat = 0.5
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                KFImage(brand.imageURL)
                    .resizable()
                    .onFailureImage(.imgDefaultBrandOriginal)
                    .cancelOnDisappear(true)
                    .frame(width: Constants.logoSize, height: Constants.logoSize)
                    .clipShape(.circle)
                    .overlay { Circle().strokeBorder(.gray100, lineWidth: Constants.logoBorderWidth) }

                Text(brand.name)
                    .nekiFont(isSelected ? .body14SemiBold : .body14Medium)
                    .foregroundStyle(isSelected ? .primary400 : .gray400)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .overlay {
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .strokeBorder(isSelected ? .primary400 : .gray75, lineWidth: Constants.borderWidth)
            }
            .contentShape(.rect(cornerRadius: Constants.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Preview

#Preview {
    NekiFlowLayout(horizontalSpacing: 6, verticalSpacing: 10) {
        ForEach(PhotoBoothListPreviewData.brands) { brand in
            BrandFilterRoundRectChip(brand: brand, isSelected: brand.id.isMultiple(of: 3)) {}
        }
    }
    .padding(20)
}
