//
//  QRCodeScanFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/16/26.
//

import Foundation
import ComposableArchitecture
import AVFoundation

@Reducer
struct QRCodeScanFeature {
    @ObservableState
    struct State {
        var isLightOn: Bool = false
        var isLoading: Bool = false
        
        var webViewURL: URL?
        
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
        case processResult(Result<ParsedQRResult, QRParseError>)
        case imageProcessingResult(Result<ImageDownsamplingProcessor.ProcessedImage, Never>)
        
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
                // TODO: QR Scanner Client에 요청하여 브랜드 별 전략이 구동될 수 있도록 해야함
                return .none
                
            case .openWebViewButtonTapped:
                state.isWebViewPresented = true
                return .none
                
            default:
                return .none
            }
        }
    }
}
