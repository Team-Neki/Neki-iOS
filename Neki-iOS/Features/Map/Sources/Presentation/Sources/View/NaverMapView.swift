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
        enum State {
            case normal, selected
        }
        
        private static let images: [PhotoBoothBrand: [State: NMFOverlayImage]] = [
            .life4cut: [.normal: NMFOverlayImage(image: .imgLife4CutPin), .selected: NMFOverlayImage(image: .imgLife4CutPinSelected)],
            .photoism: [.normal: NMFOverlayImage(image: .imgPhotoismPin), .selected: NMFOverlayImage(image: .imgPhotoismPinSelected)],
            .photogray: [.normal: NMFOverlayImage(image: .imgPhotograyPin), .selected: NMFOverlayImage(image: .imgPhotograyPinSelected)],
            .photosignature: [.normal: NMFOverlayImage(image: .imgPhotosignaturePin), .selected: NMFOverlayImage(image: .imgPhotosignaturePinSelected)],
            .harufilm: [.normal: NMFOverlayImage(image: .imgHarufilmPin), .selected: NMFOverlayImage(image: .imgHarufilmPinSelected)],
            .planBStudio: [.normal: NMFOverlayImage(image: .imgPlanBStudioPin), .selected: NMFOverlayImage(image: .imgPlanBStudioPinSelected)]
        ]
        
        static func image(for brand: PhotoBoothBrand, state: State) -> NMFOverlayImage {
            return images[brand]?[state] ?? NMFOverlayImage(image: .imgLife4CutPin)
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
        view.showLocationButton = false
        view.showCompass = false
        view.showScaleBar = false
        view.showIndoorLevelPicker = false
        view.mapView.minZoomLevel = 5.0
        view.mapView.maxZoomLevel = 18.0
        view.mapView.mapType = .basic
        
        // 초기 카메라 이동
        let startPosition = store.cameraPosition.map { NMGLatLng(lat: $0.latitude, lng: $0.longitude) } ?? Constants.defaultInitialPosition
        let cameraUpdate = NMFCameraUpdate(scrollTo: startPosition)
        cameraUpdate.animation = .fly
        cameraUpdate.animationDuration = 0.3
        view.mapView.moveCamera(cameraUpdate)
        
        // 델리게이트 연결
        view.mapView.addCameraDelegate(delegate: context.coordinator)
        view.mapView.touchDelegate = context.coordinator
        
        return view
    }
    
    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        // 현위치 모드 업데이트
        if isLocationAuthorized {
            let mode: NMFMyPositionMode = store.isUserTrackingMode ? .direction : .normal
            
            if uiView.mapView.positionMode != mode {
                uiView.mapView.positionMode = mode
            }
        } else {
            uiView.mapView.positionMode = .disabled
        }
        
        // State 변경 시 카메라 이동
        if let cameraPosition = store.cameraPosition, cameraPosition != context.coordinator.lastCameraPosition {
            let nmapCameraPosition = NMGLatLng(lat: cameraPosition.latitude, lng: cameraPosition.longitude)
            let cameraUpdate = NMFCameraUpdate(scrollTo: nmapCameraPosition)
            cameraUpdate.animation = .linear
            cameraUpdate.animationDuration = 0.3
            uiView.mapView.moveCamera(cameraUpdate)
            context.coordinator.lastCameraPosition = cameraPosition
        }
        
        // 마커 업데이트
        context.coordinator.updateMarkers(
            mapView: uiView.mapView,
            photoBooths: store.visiblePhotoBooths,
            selectedBoothID: store.selectedBooth?.id
        )
        
        let sheetHeight = store.detent.resolve(in: UIScreen.main.bounds.height, inset: .screenTabBarHeight)
        let targetInset = store.detent == .large ? .zero : UIEdgeInsets(top: .zero, left: .zero, bottom: sheetHeight, right: .zero)
        if uiView.mapView.contentInset != targetInset {
            UIView.animate(withDuration: 0.3, delay: .zero) {
                uiView.mapView.contentInset = targetInset
                uiView.layoutIfNeeded()
            }
        }
    }
}


// MARK: - NaverMapRepresentable + Nested Types

extension NaverMapRepresentable {
    @MainActor
    final class Coordinator: NSObject {
        fileprivate typealias MarkerImageResources = NaverMapRepresentable.MarkerImageResources
        
        var lastCameraPosition: GeographicCoordinate?
        
        private var markers: [UUID: NMFMarker] = [:]
        private var lastSelectedBoothID: UUID?
        
        let parent: NaverMapRepresentable
        
        init(parent: NaverMapRepresentable) { self.parent = parent }
        
        func updateMarkers(
            mapView: NMFMapView,
            photoBooths: IdentifiedArrayOf<PhotoBooth>,
            selectedBoothID: UUID?
        ) {
            let visibleIDs = Set(photoBooths.ids)
            let cachedIDs = Set(markers.keys)
            
            let idsToHide = cachedIDs.subtracting(visibleIDs)
            for id in idsToHide {
                markers[id]?.mapView = nil
            }
            
            for id in visibleIDs {
                guard let booth = photoBooths[id: id] else { continue }
                let isTargetSelected = (id == selectedBoothID)
                
                if let existingMarker = markers[id] {
                    guard existingMarker.mapView == nil else { continue }
                    configureMarkerStyle(existingMarker, brand: booth.brand, isSelected: isTargetSelected)
                    existingMarker.mapView = mapView
                } else {
                    let newMarker = createMarker(for: booth, isSelected: isTargetSelected)
                    newMarker.mapView = mapView
                    markers[id] = newMarker
                }
            }
            
            if lastSelectedBoothID != selectedBoothID {
                if let oldID = lastSelectedBoothID,
                   let oldMarker = markers[oldID],
                   oldMarker.mapView != nil {
                    let brand = photoBooths[id: oldID]?.brand ?? .life4cut
                    configureMarkerStyle(oldMarker, brand: brand, isSelected: false)
                }
                
                if let newID = selectedBoothID,
                   let newMarker = markers[newID],
                   newMarker.mapView != nil {
                    let brand = photoBooths[id: newID]?.brand ?? .life4cut
                    configureMarkerStyle(newMarker, brand: brand, isSelected: true)
                }
                
                lastSelectedBoothID = selectedBoothID
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
            marker.iconImage = MarkerImageResources.image(for: brand, state: .selected)
            marker.width = 72
            marker.height = 83
            marker.zIndex = 100 // 맨 위로
        } else {
            // 일반 상태
            marker.iconImage = MarkerImageResources.image(for: brand, state: .normal)
            marker.width = 54
            marker.height = 62
            marker.zIndex = 0
        }
    }
}


// MARK: - NaverMapRepresentable.Coordinator + NMFMapViewCameraDelegate

extension NaverMapRepresentable.Coordinator: NMFMapViewCameraDelegate {
    func mapView(_ mapView: NMFMapView, cameraWillChangeByReason reason: Int, animated: Bool) {
        if reason == NMFMapChangedByGesture {
            parent.store.send(.didDetectMapInteraction)
        }
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
        return withAnimation { parent.store.send(.didTapCloseDetail) }
    }
}

public struct NaverMapView: View {
    @Bindable var store: StoreOf<MapFeature>
    
    public init(store: StoreOf<MapFeature>) {
        self.store = store
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            
            if let selectedBooth = store.selectedBooth {
                detailCardLayer(selectedBooth)
            }
        }
        .onAppear { store.send(.onAppear) }
        .sheet(item: $store.directionSheetPhotoBooth) { photoBooth in
            DirectionAppsSheet(photoBooth: photoBooth)
        }
        .nekiSheet(selection: $store.detent) {
            NearPhotoBoothListSheet(store: store.scope(state: \.photoBoothListState, action: \.photoBoothListAction))
                .scrollDisabled(store.detent != .large)
        } controllers: {
            mapControllers
        }
        .nekiSheetBottomInset()
        .overlay(alignment: .bottom) {
            if case .large = store.detent {
                ChipFloatingButton(.map) { store.send(.didTapGoBackToMapButton, animation: .default) }.safeAreaPadding()
            }
        }
        .animation(.easeInOut, value: store.detent)
        .animation(.easeInOut, value: store.selectedBooth?.id)
    }
}


// MARK: - NaverMapView + Subviews

private extension NaverMapView {
    var mapLayer: some View {
        NaverMapRepresentable(store: store, isLocationAuthorized: store.isLocationAuthorized)
            .ignoresSafeArea(.container, edges: .top)
    }
    
    func detailCardLayer(_ photoBooth: PhotoBooth) -> some View {
        VStack {
            mapControllers
            
            HStack(spacing: 16) {
                Image(photoBooth.brand.logoImageResource)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("인생네컷") // TODO: 실제 지점 정보를 표시해야 합니다.
                            .nekiFont(.title20SemiBold)
                            .foregroundStyle(.gray900)
                        
                        Text("사당역점") // TODO: 실제 지점 정보를 표시해야 합니다.
                            .nekiFont(.body14Medium)
                            .foregroundStyle(.gray600)
                    }
                    
                    Text("300m") // TODO: 실제 거리 값을 표시해야 합니다
                        .nekiFont(.body14Medium)
                        .foregroundStyle(.gray400)
                }
                
                Spacer()
                
                Button {
                    store.send(.didTapDirectionAppsButton)
                } label: {
                    Image(.iconDirections)
                }
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .gray400, radius: 8, y: 4)
            .padding(.horizontal)
            .padding(.bottom, 72)
        }
        .transition(.move(edge: .bottom))
    }
    
    var mapControllers: some View {
        HStack {
            Button {
                store.send(.didTapCurrentLocationButton)
            } label: {
                Image(store.isUserTrackingMode ? .iconCurrentLocationActive : .iconCurrentLocationInactive)
                    .padding(8)
                    .background(.white)
                    .clipShape(.circle)
            }
            
            Spacer()
            
            if store.selectedBooth != nil {
                Button {
                    store.send(.didTapCloseDetail, animation: .default)
                } label: {
                    Image(.iconXmarkBlack)
                        .padding(8)
                        .background(.white)
                        .clipShape(.circle)
                }
            }
        }
        .padding(.horizontal, 20)
        .shadow(color: .gray400, radius: 8, y: 4)
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
