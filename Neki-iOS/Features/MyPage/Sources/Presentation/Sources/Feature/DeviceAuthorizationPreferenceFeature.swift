//
//  DeviceAuthorizationPreferenceFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/20/26.
//

import Foundation
import ComposableArchitecture
import AVFoundation
import CoreLocation
import Photos
// TODO: 알림 관련 임포팅 필요
// import Firebase

@Reducer
struct DeviceAuthorizationPreferenceFeature {
    @ObservableState
    struct State: Equatable {
        @ObservationStateIgnored private var cameraAuthorizationStatus: AVAuthorizationStatus = .notDetermined
        @ObservationStateIgnored private var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
        @ObservationStateIgnored private var photosAuthorizationStatus: PHAuthorizationStatus = .notDetermined
        
        var isCameraAuthorized: Bool { cameraAuthorizationStatus == .authorized }
        var isLocationAuthorized: Bool { locationAuthorizationStatus == .authorizedAlways || locationAuthorizationStatus == .authorizedWhenInUse }
        var isPhotosAuthorized: Bool { photosAuthorizationStatus == .authorized || photosAuthorizationStatus == .limited }
    }
    
    enum Action {
        // View Actions
        case onAppear
        case dismissButtonTapped
    }
    
    @Dependency(\.dismiss) private var dismiss
    
    var body: some ReducerOf<Self> {
        Reduce { (state: inout State, action: Action) -> Effect<Action> in
            // TODO: 액션 추가되면 로직 작성하기
            switch action {
            case .onAppear:
                // TODO: 클라이언트 의존성에서 권한 상태값 구독하기
                return .none
                
            case .dismissButtonTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
