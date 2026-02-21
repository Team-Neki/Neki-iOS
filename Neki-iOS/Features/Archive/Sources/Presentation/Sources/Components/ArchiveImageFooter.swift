//
//  ArchiveImageFooter.swift
//  Neki-iOS
//
//  Created by OneTen on 1/20/26.
//

import SwiftUI

struct ArchiveImageFooter: View {
    
    // MARK: - Properties
    
    /// 버튼 활성화 여부 (선택 모드에서는 선택된 아이템 유무, 상세 모드에서는 항상 true)
    let isEnabled: Bool
    
    /// 즐겨찾기 상태 (nil이면 버튼 숨김)
    let isFavorite: Bool?
    
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onFavorite: (() -> Void)?
    
    // MARK: - Init
    
    public init(
        isEnabled: Bool = true,
        isFavorite: Bool? = nil,
        onDownload: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onFavorite: (() -> Void)? = nil
    ) {
        self.isEnabled = isEnabled
        self.isFavorite = isFavorite
        self.onDownload = onDownload
        self.onDelete = onDelete
        self.onFavorite = onFavorite
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onDownload) {
                Image(isEnabled ? .iconDownloadFill : .iconDownload)
                    .renderingMode(.template)
                    .foregroundStyle(isEnabled ? .gray500 : .gray100)
            }
            .frame(width: 44, height: 44)
            .disabled(!isEnabled)
            
            if let isFavorite = isFavorite, let onFavorite = onFavorite {
                Button(action: onFavorite) {
                    Image(isFavorite ? .iconHeart28Fill : .iconHeart28Gray)
                        .renderingMode(.template)
                        .foregroundStyle(isFavorite ? .red : .gray300)
                }
                .padding(.leading, 12)
                .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(isEnabled ? .iconTrashFill : .iconTrash)
                    .renderingMode(.template)
                    .foregroundStyle(isEnabled ? .gray600 : .gray100)
            }
            .frame(width: 44, height: 44)
            .disabled(!isEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray75),
            alignment: .top
        )
    }
}
