//
//  ArchiveDeleteSheet.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import SwiftUI

enum ArchiveAlbumDeleteOption: Equatable {
    case withPhotos  // 사진까지 함께 삭제
    case albumOnly   // 사진은 유지하고 앨범만 삭제
}

enum ArchivePhotoDeleteOption: Equatable {
    case fromAlbumOnly // 앨범에서만 제거
    case everywhere    // 모든 위치에서 사진 제거
}

struct ArchiveDeleteSheet<T: Equatable>: View {
    
    // MARK: - Properties
    
    @Binding var selectedOption: T
    
    let title: String
    let firstOption: (value: T, text: String)
    let secondOption: (value: T, text: String)
        
    let onCancel: () -> Void
    let onConfirm: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            Text(title)
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray900)
                .frame(height: 28)
                .padding(.top, 24)
                .padding(.bottom, 24)
            
            optionRow(
                option: firstOption.value,
                title: firstOption.text
            )
            
            optionRow(
                option: secondOption.value,
                title: secondOption.text
            )
            .padding(.bottom, 16)

            GeometryReader { proxy in
                let spacing: CGFloat = 12
                let totalWidth = proxy.size.width - spacing
                let cancelWidth = totalWidth * 0.3
                let deleteWidth = totalWidth * 0.7
                
                HStack(alignment: .center, spacing: spacing) {
                    Button(action: onCancel) {
                        Text("취소")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(.gray300)
                            .frame(width: cancelWidth)
                            .frame(height: 52)
                            .background(.gray50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: onConfirm) {
                        Text("삭제하기")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(.white)
                            .frame(width: deleteWidth)
                            .frame(height: 52)
                            .background(.primary400)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .frame(height: 52)
            
        }
        .padding(.bottom, 34)
        .padding(.horizontal, 20)
        .background(.white)
    }
}


// MARK: - Subviews

private extension ArchiveDeleteSheet {
    @ViewBuilder
    func optionRow(option: T, title: String) -> some View {
        Button {
            withAnimation {
                selectedOption = option
            }
        } label: {
            HStack(spacing: 8) {
                if selectedOption == option {
                    Image(.iconCheckmark)
                }
                
                Text(title)
                    .nekiFont(selectedOption == option ? .body16SemiBold : .body16Medium)
                    .foregroundStyle(selectedOption == option ? .gray900 : .gray600)
                
                Spacer()
            }
        }
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}
