//
//  EditAlbumNameSheet.swift
//  Neki-iOS
//
//  Created by OneTen on 2/20/26.
//

import SwiftUI

struct EditAlbumNameSheet: View {
    
    // MARK: - Properties
    
    @Binding var text: String
    let errorMessage: String?
    let isConfirmEnabled: Bool
    
    // Actions
    let onCancel: () -> Void
    let onConfirm: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("앨범 이름 변경")
                .nekiFont(.title20SemiBold)
                .foregroundStyle(.gray900)
                .frame(height: 28)
                .padding(.top, 24)
                .padding(.bottom, 2)
            
            Text("변경할 앨범 이름을 입력하세요")
                .nekiFont(.body14Regular)
                .foregroundStyle(.gray700)
                .frame(height: 20)
                .padding(.bottom, 16)
            
            HStack(alignment: .center, spacing: 0) {
                TextField("앨범명을 입력하세요", text: $text)
                    .maxLength(10, text: $text)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
                    .frame(height: 50)
                
                Spacer()
                
                Text("\(text.count)/10")
                    .nekiFont(.caption12Regular)
                    .foregroundStyle(.gray300)
            }
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(errorMessage != nil ? .primary600 : .gray75, lineWidth: 1)
            )
            .padding(.bottom, 6)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .frame(height: 16)
                    .nekiFont(.caption12Regular)
                    .foregroundStyle(.primary600)
                    .padding(.leading, 2)
                    .padding(.bottom, 18)
            } else {
                Color.clear
                    .frame(height: 16)
                    .padding(.bottom, 18)
            }
            
            GeometryReader { proxy in
                let spacing: CGFloat = 12
                let totalWidth = proxy.size.width - spacing
                let cancelWidth = totalWidth * 0.3
                let addWidth = totalWidth * 0.7
                
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
                        Text("이름 변경")
                            .nekiFont(.body16SemiBold)
                            .foregroundStyle(.white)
                            .frame(width: addWidth)
                            .frame(height: 52)
                            .background(isConfirmEnabled ? .primary400 : .primary400.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isConfirmEnabled)
                }
            }
            .frame(height: 52)
            
        }
        .padding(.bottom, 34)
        .padding(.horizontal, 20)
        .background(.white)
    }
}

private extension TextField {
    func maxLength(_ length: Int, text: Binding<String>) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            if newValue.count > length {
                text.wrappedValue = String(newValue.prefix(length))
            }
        }
    }
}
