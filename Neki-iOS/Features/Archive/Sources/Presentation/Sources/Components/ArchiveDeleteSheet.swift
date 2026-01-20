//
//  ArchiveDeleteSheet.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import SwiftUI

struct ArchiveDeleteSheet: View {
    enum ArchiveDeleteOption {
        case withPhotos  // 사진까지 함께 삭제
        case albumOnly   // 사진은 유지하고 앨범만 삭제
    }
    
    // MARK: - Properties
    
    @Binding var selectedOption: ArchiveDeleteOption
    
    let onCancel: () -> Void
    let onConfirm: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("앨범을 삭제하시겠어요?")
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray900)
                .frame(height: 28)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            optionRow(
                option: .withPhotos,
                title: "사진까지 함께 삭제"
            )
            
            optionRow(
                option: .albumOnly,
                title: "사진은 유지하고 앨범만 삭제"
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
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .background(.white)
    }
}


// MARK: - Subviews

private extension ArchiveDeleteSheet {
    @ViewBuilder
    func optionRow(option: ArchiveDeleteOption, title: String) -> some View {
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
