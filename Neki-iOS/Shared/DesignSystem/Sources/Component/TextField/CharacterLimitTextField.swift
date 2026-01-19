//
//  CharacterLimitTextField.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/19/26.
//

import SwiftUI

public struct CharacterLimitTextField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    let label: String?
    let limit: Int
    let errorMessage: String?
    let prompt: String?
    
    private let cornerRadius: CGFloat = 8
    
    public init(
        _ label: String?,
        text: Binding<String>,
        prompt: String? = "",
        limit: Int = 16,
        errorMessage: String? = nil
    ) {
        self.label = label
        self.limit = limit
        self.errorMessage = errorMessage
        self.prompt = prompt
        self._text = text
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = label {
                Text(label)
                    .nekiFont(.body14Medium)
                    .foregroundStyle(.gray700)
            }
            
            HStack(spacing: .zero) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text(prompt ?? "").foregroundStyle(.gray300)
                )
                .focused($isFocused)
                .nekiFont(text.isEmpty ? .body16Regular : .body16Medium)
                .foregroundStyle(.gray900)
                
                Spacer()
                
                Text("\(text.count)/\(limit)")
                    .nekiFont(.caption12Regular)
                    .foregroundStyle(.gray300)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(.white)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .nekiFont(.caption12Regular)
                    .foregroundColor(.primary600)
            }
        }
    }
    
    private var hasError: Bool { return errorMessage != nil || text.count > limit }
    
    private var borderColor: Color {
        if hasError { return .primary600 }
        if isFocused { return .gray700 }
        return .gray300
    }
}

#Preview {
    ZStack {
        Color.gray50
        
        CharacterLimitTextField("레이블", text: .constant(""), prompt: "플레이스 홀더", limit: 16, errorMessage: "에러메세지")
            .padding()
    }
}
