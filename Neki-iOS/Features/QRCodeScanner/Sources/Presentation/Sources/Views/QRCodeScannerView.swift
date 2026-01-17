//
//  QRCodeScannerView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/17/26.
//

import SwiftUI
import ComposableArchitecture

struct QRCodeScannerView: View {
    @Bindable var store: StoreOf<QRCodeScanFeature>
    
    private let scanFrameSize: CGSize = .init(width: 304, height: 304)
    private let frameCornerRadius: CGFloat = 20
    private let bracketLineWidth: CGFloat = 6
    
    var body: some View {
        ZStack {
            CameraPreview(isTorchOn: $store.isTorchOn) { urlString in
                store.send(.codeScanned(urlString))
            }.ignoresSafeArea()
            
            Color.gray900.opacity(0.6)
                .ignoresSafeArea()
            
            VStack {
                header
                
                Spacer()
                
                title
                
                ScannerAreaView(frameSize: scanFrameSize, cornerRadius: frameCornerRadius)
                    .padding(.vertical, 40)
                
                footer
                
                Spacer()
            }
        }
    }
    
    private var header: some View {
        HStack {
            Button {
                store.send(.closeButtonTapped)
            } label: {
                Image(.iconXmarkWhite)
            }
            
            Spacer()
        }
        .padding(.top, 15)
        .padding(.leading, 20)
    }
    
    private var title: some View {
        VStack {
            Text("QR을 스캔").foregroundStyle(.linearGradient(colors: [.primary500, .primary50], startPoint: .leading, endPoint: .trailing)) +
            Text("하면").foregroundStyle(.white)
            Text("보관함에 자동 저장돼요!").foregroundStyle(.white)
        }
        .nekiFont(.title24SemiBold)
    }
    
    private var footer: some View {
        Button {
            store.send(.torchButtonTapped)
        } label: {
            Image(.iconTorchOff)
                .padding(.horizontal, 13.5)
                .padding(.vertical, 15)
                .background(.ultraThinMaterial)
                .clipShape(.circle)
        }
    }
}


// MARK: - QRCodeScannerView + Subviews

private extension QRCodeScannerView {
    struct EdgeRectangleView: View {
        let cornerRadius: CGFloat
        
        var body: some View {
            RoundedRectangle(cornerRadius: cornerRadius)
                .trim(from: 0.35, to: 0.4)
                .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .butt))
        }
    }
    
    struct ScannerAreaView: View {
        let frameSize: CGSize
        let cornerRadius: CGFloat
        
        private let rotationDegrees: [Double] = [0, 90, 180, 270]
        
        var body: some View {
            ZStack {
                Rectangle()
                    .blendMode(.destinationOut)
                    .clipShape(.rect(cornerRadius: cornerRadius))
                
                ForEach(0..<4) { index in
                    EdgeRectangleView(cornerRadius: cornerRadius)
                        .rotationEffect(.init(degrees: rotationDegrees[index]))
                }
            }
            .frame(width: frameSize.width, height: frameSize.height)
        }
    }
}

//#Preview {
//    QRCodeScannerView()
//}
