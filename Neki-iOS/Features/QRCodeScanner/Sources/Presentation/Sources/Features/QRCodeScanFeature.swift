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
        let user: User
        
        var isLightOn: Bool = false
        var isLoading: Bool = false
        
        var webViewURL: URL?
        
        var isManualDownloadNeededAlertPresented: Bool = false
        var isUnsupportedBrandAlertPresented: Bool = false
        var isExpiredAlertPresented: Bool = false
        var isWebViewPresented: Bool = false
        
        var isCameraActive: Bool {
            isLoading == false &&
            isWebViewPresented == false &&
            isManualDownloadNeededAlertPresented == false &&
            isUnsupportedBrandAlertPresented == false &&
            isExpiredAlertPresented == false
        }
    }
    
    enum Action: BindableAction {
        // View Actions
        case closeButtonTapped
        case lightButtonTapped
        case openGalleryButtonTapped
        case openSuggestBrandPage
        case openWebViewButtonTapped
        case closeWebViewButtonTapped
        case closeExpiredAlertButtonTapped
        
        // System & Alert Actions
        case codeScanned(String)
        case webViewImageDownloadResult(Result<Data, Error>)
        
        // Internal Actions
        case parseQRResult(Result<ParsedQRResult, Error>)
        case requestImageProcessing(Data)
        case imageProcessingResult(Int?)
        
        // Delegate Actions
        case addPhotoFromGalleryButtonTapped
        case addPhotoFromQRScanner(Int)
        
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
                // MARK: - User Interaction
            case .closeButtonTapped:
                return .run { _ in await dismiss() }
                
            case .lightButtonTapped:
                state.isLightOn.toggle()
                return .none
                
            case .openWebViewButtonTapped:
                state.isManualDownloadNeededAlertPresented = false
                state.isWebViewPresented = true
                return .none
                
            case .closeWebViewButtonTapped:
                state.isWebViewPresented = false
                state.webViewURL = nil
                return .none
                
            case .openGalleryButtonTapped:
                state.isUnsupportedBrandAlertPresented = false
                return .send(.addPhotoFromGalleryButtonTapped)
                
            case .openSuggestBrandPage:
                Logger.presentation.debug("브랜드 제안 페이지 이동 요청")
                return .run { _ in
                    guard let url = URL(string: "https://tally.so/r/0QekXy") else { return }
                    await openURL(url)
                }
                
            case .closeExpiredAlertButtonTapped:
                state.isExpiredAlertPresented = false
                return .none
                
                // MARK: - Scanning Flow
            case .codeScanned(let urlString):
                guard state.isLoading == false, state.isCameraActive else { return .none }
                let user = state.user
                state.isLoading = true
                Logger.presentation.debug("QR 스캔 감지: \(urlString)")
                
                return .run { send in
                    await send(.parseQRResult(Result { try await qrScannerClient.parse(urlString, user) }))
                }
                
            case let .parseQRResult(.success(parsed)):
                Logger.domain.info("✅ QR 파싱 성공: \(parsed.brand.description)")
                return .send(.requestImageProcessing(parsed.originalImage))
                
            case let .parseQRResult(.failure(error)):
                state.isLoading = false
                Logger.domain.info("QR 파싱 실패: \(error)")
                return handleError(error, state: &state)
                
                // MARK: - WebView Download Flow
            case let .webViewImageDownloadResult(.success(data)):
                state.isWebViewPresented = false
                state.isLoading = true
                Logger.presentation.debug("웹뷰에서 이미지 데이터 수신 성공")
                return .send(.requestImageProcessing(data))
                
            case let .webViewImageDownloadResult(.failure(error)):
                state.isLoading = false
                state.isWebViewPresented = false
                Logger.presentation.error("웹뷰 다운로드 실패: \(error)")
                // TODO: 토스트
                return .none
                
                // MARK: - Image Processing Logic
            case let .requestImageProcessing(imageData):
                return .run { send in
                    guard let processedID = try await qrScannerClient.processImage(imageData).first else { return await send(.imageProcessingResult(nil)) }
                    await send(.imageProcessingResult(processedID))
                } catch: { error, send in
                    Logger.domain.error("이미지 처리 실패: \(error)")
                    await send(.imageProcessingResult(nil))
                }
                
            case let .imageProcessingResult(id):
                state.isLoading = false
                guard let id else {
                    Logger.presentation.error("이미지 업로드 중 실패했거나 이미지 압축 실패")
                    // TODO: 토스트
                    return .none
                }
                return .send(.addPhotoFromQRScanner(id))
                
            default:
                return .none
            }
        }
    }
    
    private func handleError(_ error: Error, state: inout State) -> Effect<Action> {
        Logger.domain.error("QR 파싱 실패: \(error)")
        
        guard let qrError = error as? QRParseError else {
            // TODO: 알 수 없는 에러 경우에 토스트
            return .none
        }
        
        switch qrError {
        case let .fallbackToWebView(url):
            Logger.presentation.notice("⚠️ 웹뷰 폴백 UI 활성화")
            state.webViewURL = url
            state.isManualDownloadNeededAlertPresented = true
            
        case .unsupportedBrand:
            Logger.presentation.notice("⚠️ 비지원 브랜드")
            state.isUnsupportedBrandAlertPresented = true
            
        case .invalidURL:
            // TODO: 토스트 또는 로그 등 에러 추적하기
            break
            
        case .parsingFailed:
            // TODO: 토스트 또는 로그 등 에러 추적하기
            break
            
        case .urlConstructionFailed:
            // TODO: 토스트 또는 로그 등 에러 추적하기
            break
            
        case .networkError(_):
            // TODO: 토스트 또는 로그 등 에러 추적하기
            break
            
        case .imageDownloadFailed:
            Logger.presentation.notice("⚠️ 만료된 QR 코드")
            state.isExpiredAlertPresented = true
            
        @unknown default:
            break
        }
        return .none
    }
}
