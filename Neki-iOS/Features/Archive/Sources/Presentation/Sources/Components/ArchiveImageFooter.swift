//
//  ArchiveImageFooter.swift
//  Neki-iOS
//
//  Created by OneTen on 1/20/26.
//

import SwiftUI

public enum ArchiveFooterStyle {
    case detail    // 사진 상세 화면 (즐겨찾기, 메모 아이콘)
    case selection // 사진 선택 화면 (다운로드, 복제, 이동, 삭제 + 텍스트)
}

struct ArchiveImageFooter: View {
    
    // MARK: - Properties
    
    let style: ArchiveFooterStyle
    
    /// 버튼 활성화 여부
    let isEnabled: Bool
    /// 즐겨찾기 상태 (상세 모드 전용)
    let isFavorite: Bool?
    
    // 아이콘 액션
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onFavorite: (() -> Void)?
    let onTapMemo: (() -> Void)?
    let onDuplicate: (() -> Void)?
    let onMove: (() -> Void)?
    
    // MARK: - Init
    
    public init(
        style: ArchiveFooterStyle = .detail,
        isEnabled: Bool = true,
        isFavorite: Bool? = nil,
        onDownload: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onFavorite: (() -> Void)? = nil,
        onTapMemo: (() -> Void)? = nil,
        onDuplicate: (() -> Void)? = nil,
        onMove: (() -> Void)? = nil
    ) {
        self.style = style
        self.isEnabled = isEnabled
        self.isFavorite = isFavorite
        self.onDownload = onDownload
        self.onDelete = onDelete
        self.onFavorite = onFavorite
        self.onTapMemo = onTapMemo
        self.onDuplicate = onDuplicate
        self.onMove = onMove
    }
    
    // MARK: - Body
    
    var body: some View {
        if style == .selection {
            selectionModeFooter
        } else {
            detailModeFooter
        }
    }
}

extension ArchiveImageFooter {
    private var selectionModeFooter: some View {
        HStack(alignment: .center, spacing: 0) {
            selectionButton(
                title: "다운로드",
                icon: Image(isEnabled ? .iconDownloadFill : .iconDownload),
                action: onDownload
            )
            
            selectionButton(
                title: "사진 복제",
                icon: Image(isEnabled ? .iconDuplicateFill : .iconDuplicate),
                action: onDuplicate ?? {}
            )
            
            selectionButton(
                title: "사진 이동",
                icon: Image(isEnabled ? .iconMoveFill : .iconMove),
                action: onMove ?? {}
            )
            
            selectionButton(
                title: "삭제",
                icon: Image(isEnabled ? .iconTrashFill : .iconTrash),
                action: onDelete
            )
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray75),
            alignment: .top
        )
    }
    
    // 버튼 공통 뷰 빌더
    @ViewBuilder
    private func selectionButton(title: String, icon: Image, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(isEnabled ? .gray700 : .gray200)
                
                Text(title)
                    .nekiFont(.body14Medium)
                    .foregroundStyle(isEnabled ? .gray700 : .gray400)

            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
    }
        
    private var detailModeFooter: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onDownload) {
                Image(isEnabled ? .iconDownloadFill : .iconDownload)
                    .foregroundStyle(isEnabled ? .gray700 : .gray200)
            }
            .disabled(!isEnabled)
            
            if let isFavorite = isFavorite, let onFavorite = onFavorite {
                Button(action: onFavorite) {
                    Image(isFavorite ? .iconHeart28Fill : .iconHeart28Gray)
                }
                .padding(.leading, 16)
            }
            
            if let onTapMemo = onTapMemo {
                Button(action: onTapMemo) {
                    Image(.iconNote)
                        .foregroundStyle(.gray700)
                }
                .padding(.leading, 16)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(isEnabled ? .iconTrashFill : .iconTrash)
                    .renderingMode(.template)
                    .foregroundStyle(isEnabled ? .gray700 : .gray100)
            }
            .disabled(!isEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray75),
            alignment: .top
        )
    }
}
