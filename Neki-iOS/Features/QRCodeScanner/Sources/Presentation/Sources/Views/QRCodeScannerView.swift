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
    
    @State private var currentZoomFactor: CGFloat = 1.0
    @State private var lastZoomFactor: CGFloat = 1.0
    
    private let scanFrameSize: CGSize = .init(width: 304, height: 304)
    private let frameCornerRadius: CGFloat = 20
    private let bracketLineWidth: CGFloat = 6
    
    var body: some View {
        ZStack(alignment: .top) {
            CameraPreview(isTorchOn: store.isLightOn, isActive: store.isCameraActive, zoomFactor: currentZoomFactor) { urlString in
                store.send(.codeScanned(urlString))
            }
            .ignoresSafeArea()
            
            Color.gray900.opacity(0.6)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            VStack {
                header
                
                title
                    .padding(.top, 40)
                
                ScannerAreaView(frameSize: scanFrameSize, cornerRadius: frameCornerRadius)
                    .padding(.top, 32)
                    .allowsHitTesting(false)
                
                footer
                    .padding(.top, 40)
            }
            
            if store.isWebViewPresented, let url = store.webViewURL {
                webViewLayer(url: url)
            }
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    guard store.isCameraActive else { return }
                    let newZoom = lastZoomFactor * value.magnification
                    currentZoomFactor = min(max(newZoom, CameraZoomFactor.defaultMinZoomFactor), CameraZoomFactor.defaultMaxZoomFactor)
                }
                .onEnded { _ in
                    guard store.isCameraActive else { return }
                    lastZoomFactor = currentZoomFactor
                }
        )
        .nekiAlert(
            isPresented: $store.isManualDownloadNeededAlertPresented,
            style: .plain,
            title: "갤러리에 사진을 먼저 다운받아주세요.",
            subtitle: "해당 브랜드는 웹사이트에서 사진을 저장해야 네키에 자동으로 저장돼요.",
            confirmText: "사진 다운로드하러 가기",
            isProcessing: false,
            onConfirm: { store.send(.openWebViewButtonTapped) }
        )
        .nekiAlert(
            isPresented: $store.isUnsupportedBrandAlertPresented,
            style: .primarySecondary,
            title: "지원하지 않는 브랜드예요.",
            subtitle: "갤러리에서 사진을 추가해 바로 저장할 수 있어요.\n원하는 브랜드가 있다면 제안해주세요!",
            confirmText: "갤러리에서 추가하기",
            secondaryText: "브랜드 제안하기",
            onConfirm: { store.send(.addPhotoFromGalleryButtonTapped) },
            onSecondary: { store.send(.openSuggestBrandPage) }
        )
        .nekiAlert(
            isPresented: $store.isExpiredAlertPresented,
            style: .plain,
            title: "QR이 만료되었어요.",
            subtitle: "일정 시간이 지나면 QR로는 더 이상 불러올 수 없어요. 이미 저장된 사진이 있다면 갤러리에서 추가해보세요.",
            confirmText: "갤러리에서 추가하기",
            onConfirm: { store.send(.closeExpiredAlertButtonTapped) }
        )
        .nekiLoading(isPresented: store.isLoading)
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
        .padding(.vertical, 15)
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
            store.send(.lightButtonTapped)
        } label: {
            Image(store.isLightOn ? .iconLightOn : .iconLightOff)
                .padding(.horizontal, 13.5)
                .padding(.vertical, 15)
                .background(.ultraThinMaterial)
                .clipShape(.circle)
        }
    }
    
    private func webViewLayer(url: URL) -> some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack {
                DownloadableWebView(url: url) { data in
                    store.send(.webViewImageDownloadResult(.success(data)))
                } onError: { error in
                    store.send(.webViewImageDownloadResult(.failure(error)))
                }
                
                Button {
                    store.send(.closeWebViewButtonTapped)
                } label: {
                    Text("닫기")
                }
            }
        }
        .transition(.move(edge: .bottom))
        .zIndex(2)
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
