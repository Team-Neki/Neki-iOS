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
        var scannedImage: UIImage? // TODO: 임시코드
        
        var isManualDownloadNeededAlertPresented: Bool = false
        var isWebViewPresented: Bool = false
    }
    
    enum Action: BindableAction {
        // View Actions
        case closeButtonTapped
        case lightButtonTapped
        case codeScanned(String)
        
        // WebView & Alert Actions
        case openWebViewButtonTapped
        case webViewImageDownloadResult(Result<Data, Error>)
        
        // Internal Actions
        case processResult(Result<ParsedQRResult, Error>)
        case imageProcessingResult(ImageDownsamplingProcessor.ProcessedImage?)
        
        // Binding Actions
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.qrScannerClient) private var qrScannerClient
    
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
                    let processed = await qrScannerClient.processImage(parsed.originalImage)
                    await send(.imageProcessingResult(processed))
                }
                
            case let .processResult(.failure(error)):
                state.isLoading = false
                
                Logger.domain.error("QR 파싱 전략 실패: \(error.localizedDescription)")
                
                if let qrError = error as? QRParseError,
                   case let .fallbackToWebView(url) = qrError {
                    Logger.presentation.notice("⚠️ 웹뷰 폴백 UI 활성화: \(url.absoluteString)")
                    state.webViewURL = url
                    state.isManualDownloadNeededAlertPresented = true
                    return .none
                }
                
                Logger.presentation.error("❌ 지원하지 않거나 유효하지 않은 QR")
                // TODO: 사용자에게 토스트 메시지 표시
                return .none
                
            case let .imageProcessingResult(processed):
                state.isLoading = false
                // TODO: 이미지 표시 하지말고 즉시 S3로 전송해야함 (WIP)
                guard let data = processed?.data, let image = UIImage(data: data) else {
                    Logger.data.error("❌ 이미지 데이터 변환 실패")
                    return .none
                }
                state.scannedImage = image
                Logger.data.info("🎉 최종 이미지 확보 완료 (Size: \(data.count) bytes)")
                return .none
                
            case .openWebViewButtonTapped:
                state.isManualDownloadNeededAlertPresented = false
                state.isWebViewPresented = true
                return .none
                
            case let .webViewImageDownloadResult(.success(data)):
                state.isWebViewPresented = false
                state.isLoading = true
                Logger.data.debug("웹뷰에서 이미지 데이터 수신 성공")
                
                return .run { send in
                    guard let processed = await qrScannerClient.processImage(data) else {
                        return await send(.imageProcessingResult(nil))
                    }
                    return await send(.imageProcessingResult(processed))
                }
                
            case let .webViewImageDownloadResult(.failure(error)):
                print("웹뷰 다운로드 실패: \(error)")
                return .none
                
            default:
                return .none
            }
        }
    }
}
