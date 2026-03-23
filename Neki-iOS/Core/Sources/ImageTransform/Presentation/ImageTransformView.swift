//
//  ImageTransformView.swift
//  Neki-iOS
//
//  Created by OneTen on 3/13/26.
//

import SwiftUI
import ComposableArchitecture

public struct ImageTransformView: View {
    let store: StoreOf<ImageTransformFeature>
    
    public init(store: StoreOf<ImageTransformFeature>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Text("AI 스케치 변환 🎨")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            ZStack {
                if let outputImage = store.outputImage {
                    Image(uiImage: outputImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 450)
                        .cornerRadius(16)
                        .shadow(radius: 5)
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                } else if let inputImage = store.inputImage {
                    Image(uiImage: inputImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 450)
                        .cornerRadius(16)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 450)
                        .cornerRadius(16)
                        .overlay(Text("이미지를 선택해주세요").foregroundColor(.gray))
                }
                
                if store.isProcessing {
                    Color.black.opacity(0.3)
                        .cornerRadius(16)
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                        Text("스케치 그리는 중...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }
            .padding(.horizontal, 20)
            
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            if store.outputImage != nil {
                Button(action: {
                    store.send(.revertButtonTapped)
                }) {
                    Text("원본 되돌리기")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                }
                .disabled(store.isProcessing)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
            } else {
                Button(action: {
                    store.send(.transformButtonTapped)
                }) {
                    Text("스케치로 변환하기")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(store.isProcessing || store.inputImage == nil ? Color.gray.opacity(0.5) : Color.blue)
                        .cornerRadius(16)
                }
                .disabled(store.isProcessing || store.inputImage == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}
