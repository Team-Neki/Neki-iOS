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
    /// QR Code 스캐너 관련 얼럿 네임스페이스
    enum ScannerAlert {
        case manualDownloadRequired
    }
    
    @ObservableState
    struct State {
        var isLightOn: Bool = false
        var scannedURL: URL?
        
        var alert: ScannerAlert?
    }
    
    enum Action: BindableAction {
        // View Actions
        case closeButtonTapped
        case lightButtonTapped
        case codeScanned(String)
        
        // Internal Actions
        case codeDidScan(URL?)
        
        // Binding Actions
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.dismiss) private var dismiss
    
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
                return .run { send in await send(.codeDidScan(URL(string: urlString))) }
                
            case .codeDidScan(let url):
                // TODO: 확보한 URL로 파싱
                return .none
                
            default:
                return .none
            }
        }
    }
}
