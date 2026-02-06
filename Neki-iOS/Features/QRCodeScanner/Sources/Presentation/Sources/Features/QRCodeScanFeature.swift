//
//  QRCodeScanFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/16/26.
//

import UIKit
import ComposableArchitecture
import AVFoundation
import os

@Reducer
struct QRCodeScanFeature {
    @ObservableState
    struct State {
        var isLightOn: Bool = false
        var isLoading: Bool = false
        
        var webViewURL: URL?
        
        var isManualDownloadNeededAlertPresented: Bool = false
        var isUnsupportedBrandAlertPresented: Bool = false
        var isWebViewPresented: Bool = false
    }
    
    enum Action: BindableAction {
        // View Actions
        case closeButtonTapped
        case lightButtonTapped
        case codeScanned(String)
        case openSuggestBrandPage
        
        // WebView & Alert Actions
        case openWebViewButtonTapped
        case closeWebViewButtonTapped
        case webViewImageDownloadResult(Result<Data, Error>)
        
        // Internal Actions
        case processResult(Result<ParsedQRResult, Error>)
        case imageProcessingResult(Int?)
        
        // Delegate Actions
        case addPhotoFromGalleryButtonTapped
        
        // Binding Actions
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.qrScannerClient) private var qrScannerClient
    @Dependency(\.openURL) private var openURL
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            switch action {
            case .closeButtonTapped:
                return .run { _ in await dismiss() }
                
            case .lightButtonTapped:
                state.isLightOn.toggle()
                return .none
                
            case .codeScanned(let urlString):
                guard state.isLoading == false else { return .none }
                state.isLoading = true
                
                Logger.presentation.debug("QR 스캔 감지: \(urlString)")
                
                return .run { send in
                    await send(.processResult(Result { try await qrScannerClient.parse(urlString) }))
                }
                
            case let .processResult(.success(parsed)):
                Logger.domain.info("✅ QR 파싱 성공: \(parsed.brand.displayName)")
                
                return .run { send in
                    guard let processedID = try await qrScannerClient.processImage(parsed.originalImage).first else {
                        return await send(.imageProcessingResult(nil))
                    }
                    await send(.imageProcessingResult(processedID))
                }
                
            case let .processResult(.failure(error)):
                state.isLoading = false
                
                Logger.domain.error("QR 파싱 전략 실패: \(error.localizedDescription)")
                
                guard let qrError = error as? QRParseError else {
                    Logger.presentation.error("❌ 알 수 없는 QR스캔 에러 발생: \(error)")
                    // TODO: 사용자에게 토스트 메시지 표시
                    return .none
                }
                
                if case let .fallbackToWebView(url) = qrError {
                    Logger.presentation.notice("⚠️ 웹뷰 폴백 UI 활성화: \(url.absoluteString)")
                    state.webViewURL = url
                    state.isManualDownloadNeededAlertPresented = true
                    return .none
                }
                
                if case .unsupportedBrand = qrError {
                    Logger.presentation.notice("⚠️ 비지원 브랜드 인식됨")
                    state.isUnsupportedBrandAlertPresented = true
                    return .none
                }
                
                // TODO: 토스트 띄우기
                return .none
                
            case .openWebViewButtonTapped:
                state.isManualDownloadNeededAlertPresented = false
                state.isWebViewPresented = true
                return .none
                
            case .closeWebViewButtonTapped:
                state.isWebViewPresented = false
                state.webViewURL = nil
                
            case let .webViewImageDownloadResult(.success(data)):
                state.isWebViewPresented = false
                state.isLoading = true
                Logger.data.debug("웹뷰에서 이미지 데이터 수신 성공")
                
                return .run { send in
                    guard let processedID = try await qrScannerClient.processImage(data).first else {
                        return await send(.imageProcessingResult(nil))
                    }
                    await send(.imageProcessingResult(processedID))
                }
                
            case let .webViewImageDownloadResult(.failure(error)):
                // TODO: 에러 토스트 필요
                state.isLoading = false
                state.isWebViewPresented = false
                state.webViewURL = nil
                return .none
                
            case .openSuggestBrandPage:
                Logger.presentation.debug("브랜드 제안 페이지 이동 요청")
                return .run { _ in
                    guard let url = URL(string: "https://tally.so/r/0QekXy") else { return }
                    await openURL(url)
                }
                
            default:
                return .none
            }
        }
    }
}
