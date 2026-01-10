//
//  NaverMapView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
import NMapsMap

struct NaverMapRepresentable: UIViewRepresentable {
    private enum Constants {
        static let defaultInitialPosition: NMGLatLng = .init(lat: 37.498095, lng: 127.027610)
    }
    
    /// 마커 이미지 리소스
    fileprivate enum MarkerImageResources {
        static let harufilm = NMFOverlayImage(image: .imgHarufilmPin)
        static let life4cut = NMFOverlayImage(image: .imgLife4CutPin)
        static let photogray = NMFOverlayImage(image: .imgPhotoismPin)
        static let photoism = NMFOverlayImage(image: .imgPhotoismPin)
        static let photosignature = NMFOverlayImage(image: .imgPhotosignaturePin)
        static let planBStudio = NMFOverlayImage(image: .imgPlanBStudioPin)
        
        static func brand(_ brand: PhotoBoothBrand) -> NMFOverlayImage {
            switch brand {
            case .life4cut: return Self.life4cut
            case .photoism: return Self.photoism
            case .photogray: return Self.photogray
            case .photosignature: return Self.photosignature
            case .harufilm: return Self.harufilm
            case .planBStudio: return Self.planBStudio
            }
        }
    }
    
    @Bindable var store: StoreOf<MapFeature>
    let isLocationAuthorized: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> NMFNaverMapView {
        let view = NMFNaverMapView()
        
        // UI 초기 설정
        view.showZoomControls = false
        view.showLocationButton = isLocationAuthorized
        view.showCompass = false
        view.showScaleBar = false
        view.showIndoorLevelPicker = false
        view.mapView.minZoomLevel = 5.0
        view.mapView.maxZoomLevel = 18.0
        
        // 초기 카메라 이동
        let startPosition = store.cameraPosition.map { NMGLatLng(lat: $0.latitude, lng: $0.longitude) } ?? Constants.defaultInitialPosition
        let cameraUpdate = NMFCameraUpdate(scrollTo: startPosition)
        view.mapView.moveCamera(cameraUpdate)
        
        // 델리게이트 연결
        view.mapView.addCameraDelegate(delegate: context.coordinator)
        view.mapView.touchDelegate = context.coordinator
        
        return view
    }
    
    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        // 현위치 모드 업데이트
        uiView.mapView.positionMode = isLocationAuthorized ? .normal : .disabled
        
        // State 변경 시 카메라 이동
        if let cameraPosition = store.cameraPosition {
            let nmapCameraPosition = NMGLatLng(lat: cameraPosition.latitude, lng: cameraPosition.longitude)
            let cameraUpdate = NMFCameraUpdate(scrollTo: nmapCameraPosition)
            cameraUpdate.animation = .linear
            uiView.mapView.moveCamera(cameraUpdate)
        }
        
        // 마커 업데이트
        context.coordinator.updateMarkers(
            mapView: uiView.mapView,
            photoBooths: store.visiblePhotoBooths,
            selectedBoothID: store.selectedBooth?.id
        )
    }
}


// MARK: - NaverMapRepresentable + Nested Types

extension NaverMapRepresentable {
    @MainActor
    final class Coordinator: NSObject {
        fileprivate typealias MarkerImageResources = NaverMapRepresentable.MarkerImageResources
        
        private var markers: [UUID: NMFMarker] = [:]
        private var updateTask: Task<Void, Never>?
        
        let parent: NaverMapRepresentable
        
        init(parent: NaverMapRepresentable) { self.parent = parent }
        
        func updateMarkers(
            mapView: NMFMapView,
            photoBooths: IdentifiedArrayOf<PhotoBooth>,
            selectedBoothID: UUID?
        ) {
            updateTask?.cancel()
            
            let currentMarkerIDs = Set(markers.keys)
            
            updateTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self, Task.isCancelled == false else { return }
                
                let newIDs = Set(photoBooths.ids)
                let idsToRemove = currentMarkerIDs.subtracting(newIDs)
                let idsToAdd = newIDs.subtracting(currentMarkerIDs)
                let idsToCheck = newIDs.intersection(currentMarkerIDs)
                
                await MainActor.run {
                    guard Task.isCancelled == false else { return }
                    
                    // 마커 삭제
                    for id in idsToRemove {
                        self.markers[id]?.mapView = nil
                        self.markers.removeValue(forKey: id)
                    }
                    
                    // 마커 추가
                    for id in idsToAdd {
                        guard let booth = photoBooths[id: id] else { continue }
                        let isSelected = (id == selectedBoothID)
                        let marker = self.createMarker(for: booth, isSelected: isSelected)
                        
                        marker.mapView = mapView
                        self.markers[id] = marker
                    }
                    
                    // 마커 갱신
                    for id in idsToCheck {
                        guard let marker = self.markers[id], let booth = photoBooths[id: id] else { continue }
                        let isSelected = (id == selectedBoothID)
                        let wasSelected = marker.userInfo["isSelected"] as? Bool ?? false
                        
                        guard wasSelected != isSelected else { continue }
                        self.configureMarkerStyle(marker, brand: booth.brand, isSelected: isSelected)
                    }
                }
            }
        }
    }
}


// MARK: - NaverMapRepresentable.Coordinator + Factory Helpers

private extension NaverMapRepresentable.Coordinator {
    /// 새 마커 생성
    func createMarker(for photoBooth: PhotoBooth, isSelected: Bool) -> NMFMarker {
        let marker = NMFMarker()
        marker.position = NMGLatLng(lat: photoBooth.coordinate.latitude, lng: photoBooth.coordinate.longitude)
        
        // 기본 캡션 설정
        marker.captionText = photoBooth.name
        marker.captionColor = .init(hex: 0x202227)
        marker.captionHaloColor = .white
        marker.captionTextSize = 12
        
        // 탭 핸들러 설정
        marker.touchHandler = { [weak self] _ in
            self?.parent.store.send(.didTapBooth(photoBooth))
            return true
        }
        
        // 스타일 설정
        configureMarkerStyle(marker, brand: photoBooth.brand, isSelected: isSelected)
        
        return marker
    }
    
    /// 마커 스타일 설정
    func configureMarkerStyle(_ marker: NMFMarker, brand: PhotoBoothBrand, isSelected: Bool) {
        marker.userInfo["isSelected"] = isSelected
        
        if isSelected {
            // MARK: - 선택 상태의 이미지 리소스 추가해야합니다. 아래는 예제코드 입니다.
            marker.iconImage = MarkerImageResources.brand(brand) // 임시: 동일 이미지 사용
            marker.width = 64   // 확대
            marker.height = 73  // 확대
            marker.zIndex = 100 // 맨 위로
        } else {
            // 일반 상태
            marker.iconImage = MarkerImageResources.brand(brand)
            marker.width = 54
            marker.height = 61.5
            marker.zIndex = 0
        }
    }
}


// MARK: - NaverMapRepresentable.Coordinator + NMFMapViewCameraDelegate

extension NaverMapRepresentable.Coordinator: NMFMapViewCameraDelegate {
    func mapView(_ mapView: NMFMapView, cameraWillChangeByReason reason: Int, animated: Bool) {
        parent.store.send(.cameraMotionStarted)
    }
    
    func mapViewCameraIdle(_ mapView: NMFMapView) {
        let nmapBounds = mapView.contentBounds
        parent.store.send(.cameraMotionEnded(nmapBounds.toDomain()))
    }
}


// MARK: - NaverMapRepresentable.Coordinator + NMFMapViewTouchDelegate

extension NaverMapRepresentable.Coordinator: NMFMapViewTouchDelegate {
    func mapView(_ mapView: NMFMapView, didTapMap latlng: NMGLatLng, point: CGPoint) {
        parent.store.send(.didTapCloseDetail)
    }
}

public struct NaverMapView: View {
    @Bindable var store: StoreOf<MapFeature>
    
    public init(store: StoreOf<MapFeature>) {
        self.store = store
    }
    
    public var body: some View {
        ZStack {
            mapLayer
        }
        .onAppear { store.send(.onAppear) }
        .nekiSheet(selection: $store.detent) {
            NearPhotoBoothListSheet(store: store.scope(state: \.photoBoothListState, action: \.photoBoothListAction))
        }
        .nekiSheetBottomInset()
        .overlay(alignment: .bottom) {
            if case .large = store.detent {
                ChipFloatingButton(.map) { store.send(.didTapGoBackToMapButton) }.safeAreaPadding()
            }
        }
    }
}


// MARK: - NaverMapView + Subviews

private extension NaverMapView {
    var mapLayer: some View {
        Group {
            if store.isSDKAuthSuccessful {
                NaverMapRepresentable(store: store, isLocationAuthorized: store.isLocationAuthorized)
                    .ignoresSafeArea(.container, edges: .top)
            } else {
                errorLayer
            }
        }
    }
    
    @ViewBuilder
    var permissionLayer: some View {
        if store.isLocationAuthorized && store.isSDKAuthSuccessful {
            permissionDeniedLayer
        }
    }
    
    var errorLayer: some View {
        ContentUnavailableView("지도 로드 실패", image: "excalmationmark.triangle", description: Text("네이버 지도 인증에 실패했습니다."))
    }
    
    var permissionDeniedLayer: some View {
        VStack {
            Text("위치 권한 확보 필요!!")
            
            Button {
                store.send(.openAppSettings)
            } label: {
                Text("설정 앱으로 이동")
            }
        }
    }
}


// MARK: - Naver SDK Extension

extension NMGLatLngBounds {
    func toDomain() -> GeographicBoundingBox {
        GeographicBoundingBox(
            minLatitude: southWest.lat,
            minLongitude: southWest.lng,
            maxLatitude: northEast.lat,
            maxLongitude: northEast.lng
        )
    }
}

extension NMGLatLng {
    func toDomain() -> GeographicCoordinate {
        GeographicCoordinate(latitude: self.lat, longitude: self.lng)
    }
}

#Preview {
    TabView {
        NaverMapView(store: Store(initialState: MapFeature.State(), reducer: { MapFeature() }))
            .tabItem {
                Label("네컷지도", systemImage: "mappin.and.ellipse")
            }
    }
}
