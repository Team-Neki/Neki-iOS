//
//  NaverMapView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
import NMapsMap
import Kingfisher
import os

fileprivate enum Constants {
    // Map Settings
    static let defaultInitialPosition = NMGLatLng(lat: 37.498095, lng: 127.027610)
    static let animationDuration: TimeInterval = 0.3
    static let minZoomLevel: Double = 12.0
    static let maxZoomLevel: Double = 20.0
    static let initialZoomLevel: Double = 14.0
    
    // Marker Size
    static let normalSize = CGSize(width: 54, height: 62)
    static let selectedSize = CGSize(width: 72, height: 83)
    static let zIndexNormal: Int = 0
    static let zIndexSelected: Int = 100
}

struct NaverMapRepresentable: UIViewRepresentable {
    @Bindable var store: StoreOf<MapFeature>
    let isLocationAuthorized: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> NMFNaverMapView {
        let view = NMFNaverMapView()
        
        // UI 초기 설정
        configureMapView(view)
        
        // 초기 카메라 이동
        let startPosition = Constants.defaultInitialPosition
        let cameraUpdate = NMFCameraUpdate(scrollTo: startPosition, zoomTo: Constants.initialZoomLevel)
        cameraUpdate.animation = .none
        view.mapView.moveCamera(cameraUpdate)
        
        // 델리게이트 연결
        view.mapView.addCameraDelegate(delegate: context.coordinator)
        view.mapView.touchDelegate = context.coordinator
        
        return view
    }
    
    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        // 현위치 모드 업데이트
        updateLocationOverlay(uiView.mapView, isAuthorized: isLocationAuthorized)
        
        // State 변경 시 카메라 이동
        if context.coordinator.isMapLoaded {
            updateCameraPosition(uiView.mapView, context: context)
        }
        
        // 마커 업데이트
        context.coordinator.updateMarkers(
            mapView: uiView.mapView,
            photoBooths: store.visiblePhotoBooths,
            selectedBoothID: store.selectedBooth?.id
        )
        
        updateContentInset(uiView.mapView)
    }
}


// MARK: - NaverMapRepresentable + Helper Methods

private extension NaverMapRepresentable {
    func configureMapView(_ view: NMFNaverMapView) {
        view.showZoomControls = false
        view.showLocationButton = false
        view.showCompass = false
        view.showScaleBar = false
        view.showIndoorLevelPicker = false
        view.mapView.minZoomLevel = Constants.minZoomLevel
        view.mapView.maxZoomLevel = Constants.maxZoomLevel
        view.mapView.zoomLevel = Constants.initialZoomLevel
        view.mapView.extent = NMGLatLngBounds(southWestLat: 31.43, southWestLng: 122.37, northEastLat: 44.35, northEastLng: 132)
        view.mapView.mapType = .basic
    }
    
    func updateLocationOverlay(_ mapView: NMFMapView, isAuthorized: Bool) {
        if isLocationAuthorized {
            let mode: NMFMyPositionMode = store.isUserTrackingMode ? .direction : .normal
            
            if mapView.positionMode != mode {
                mapView.positionMode = mode
            }
        } else {
            mapView.positionMode = .disabled
        }
    }
    
    func updateCameraPosition(_ mapView: NMFMapView, context: Context) {
        guard let cameraPosition = store.cameraPosition,
              cameraPosition != context.coordinator.lastCameraPosition
        else { return }
        let nmapCameraPosition = NMGLatLng(lat: cameraPosition.latitude, lng: cameraPosition.longitude)
        let cameraUpdate = NMFCameraUpdate(scrollTo: nmapCameraPosition)
        cameraUpdate.animation = .linear
        cameraUpdate.animationDuration = Constants.animationDuration
        mapView.moveCamera(cameraUpdate)
        context.coordinator.lastCameraPosition = cameraPosition
    }
    
    func updateContentInset(_ mapView: NMFMapView) {
        let sheetHeight = store.detent.resolve(in: UIScreen.main.bounds.height, inset: .screenTabBarHeight)
        let targetInset = store.detent == .large ? .zero : UIEdgeInsets(top: .zero, left: .zero, bottom: sheetHeight, right: .zero)
        if mapView.contentInset != targetInset {
            UIView.animate(withDuration: Constants.animationDuration, delay: .zero) {
                mapView.contentInset = targetInset
                mapView.layoutIfNeeded()
            }
        }
    }
}


// MARK: - NaverMapRepresentable + Nested Types

extension NaverMapRepresentable {
    @MainActor
    final class Coordinator: NSObject {
        typealias BoothID = Int
        typealias BrandID = Int
        
        private let defaultBrandImage: UIImage = UIImage(resource: .imgDefaultBrandOriginal)
        private lazy var defaultNormalOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(brandImage: defaultBrandImage, isSelected: false)
            return NMFOverlayImage(image: image)
        }()
        private lazy var defaultSelectedOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(brandImage: defaultBrandImage, isSelected: true)
            return NMFOverlayImage(image: image)
        }()
        
        var lastCameraPosition: GeographicCoordinate?
        var isMapLoaded: Bool = false
        
        private var markers: [BoothID: NMFMarker] = [:]
        private var markerImageTasks: [BoothID: Task<Void, Never>] = [:]
        private var overlayImageCache: [String: NMFOverlayImage] = [:]
        private var lastSelectedBoothID: Int?
        
        let parent: NaverMapRepresentable
        
        init(parent: NaverMapRepresentable) { self.parent = parent }
        
        func updateMarkers(
            mapView: NMFMapView,
            photoBooths: IdentifiedArrayOf<PhotoBooth>,
            selectedBoothID: BoothID?
        ) {
            let newIDs = Set(photoBooths.ids)
            let currentIDs = Set(markers.keys)
            
            let idsToRemove = currentIDs.subtracting(newIDs)
            for id in idsToRemove {
                markers[id]?.mapView = nil
                markers[id] = nil
                markerImageTasks[id]?.cancel()
                markerImageTasks[id] = nil
            }
            
            for booth in photoBooths {
                let isSelected = (booth.id == selectedBoothID)
                
                if let existingMarker = markers[booth.id] {
                    updateMarkerStyleIfNeeded(existingMarker, booth: booth, isSelected: isSelected)
                } else {
                    let newMarker = createMarker(for: booth)
                    newMarker.mapView = mapView
                    markers[booth.id] = newMarker
                    updateMarkerStyleIfNeeded(newMarker, booth: booth, isSelected: isSelected, isInitial: true)
                }
            }
        }
    }
}


// MARK: - NaverMapRepresentable.Coordinator + Factory Helpers

private extension NaverMapRepresentable.Coordinator {
    func createMarker(for booth: PhotoBooth) -> NMFMarker {
        let marker = NMFMarker()
        marker.position = NMGLatLng(lat: booth.coordinate.latitude, lng: booth.coordinate.longitude)
        marker.captionText = "\(booth.brand.name)\n\(booth.name)"
        marker.captionColor = .init(hex: 0x202227)
        marker.captionHaloColor = .white
        marker.captionTextSize = 12
        marker.anchor = CGPoint(x: 0.5, y: 1.0)
        
        marker.touchHandler = { [weak self] _ in
            self?.parent.store.send(.didTapBooth(booth))
            return true
        }
        return marker
    }
    
    func updateMarkerStyleIfNeeded(_ marker: NMFMarker, booth: PhotoBooth, isSelected: Bool, isInitial: Bool = false) {
        let currentSelectionState = marker.userInfo["isSelected"] as? Bool ?? false
        if isInitial == false, currentSelectionState == isSelected { return }
        marker.userInfo["isSelected"] = isSelected
        marker.zIndex = isSelected ? Constants.zIndexSelected : Constants.zIndexNormal
        let cacheKey = createCacheKey(brandID: booth.brand.id, isSelected: isSelected)
        if let cachedOverlay = overlayImageCache[cacheKey] {
            marker.iconImage = cachedOverlay
            return
        }
        
        guard let url = booth.brand.imageURL else {
            applyDefaultOverlay(to: marker, isSelected: isSelected)
            return
        }
        
        markerImageTasks[booth.id]?.cancel()
        markerImageTasks[booth.id] = Task { [weak self] in
            guard let self else { return }
            let resource = KF.ImageResource(downloadURL: url, cacheKey: url.absoluteString)
            
            do {
                let result = try await KingfisherManager.shared.retrieveImage(with: resource)
                guard Task.isCancelled == false else { return }
                let renderedOverlay: NMFOverlayImage? = await Task.detached(priority: .userInitiated) {
                    guard Task.isCancelled == false else { return nil }
                    let finalImage = MarkerImageRenderer.render(brandImage: result.image, isSelected: isSelected)
                    return NMFOverlayImage(image: finalImage)
                }.value
                
                guard let overlay = renderedOverlay, Task.isCancelled == false else { return }
                applyOverlay(to: marker, overlay: overlay, isSelected: isSelected, cacheKey: cacheKey)
            } catch {
                guard Task.isCancelled == false else { return }
                Logger.presentation.error("Brand Image Download Failed for Marker: \(booth.id) - \(error)")
                applyDefaultOverlay(to: marker, isSelected: isSelected)
            }
        }
    }
    
    func applyOverlay(to marker: NMFMarker, overlay: NMFOverlayImage, isSelected: Bool, cacheKey: String) {
        let currentMarkerStats = marker.userInfo["isSelected"] as? Bool ?? isSelected
        guard currentMarkerStats == isSelected else { return }
        overlayImageCache[cacheKey] = overlay
        marker.iconImage = overlay
    }
    
    func applyDefaultOverlay(to marker: NMFMarker, isSelected: Bool) {
        let targetOverlay = isSelected ? defaultSelectedOverlay : defaultNormalOverlay
        marker.iconImage = targetOverlay
    }
    
    func createCacheKey(brandID: BrandID, isSelected: Bool) -> String {
        "brand_\(brandID)_selected_\(isSelected)"
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
        let geographicBounds = nmapBounds.toDomain()
        if isMapLoaded == false {
            isMapLoaded = true
            parent.store.send(.mapLoaded(geographicBounds))
        }
        parent.store.send(.cameraMotionEnded(geographicBounds))
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
        .overlay(alignment: .top) {
            if store.isSearchHereButtonVisible {
                searchHereControl
            }
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
                ChipFloatingButton(.map) { store.send(.didTapGoBackToMapButton, animation: .default) }
                    .padding(.bottom, 52)
                    .safeAreaPadding()
            }
        }
        .animation(.easeInOut, value: store.detent)
        .animation(.easeInOut, value: store.selectedBooth?.id)
        .nekiAlert(
            isPresented: $store.isPermissionAlertPresented,
            style: .cancelable,
            title: "위치 권한",
            subtitle: "주변 포토부스를 찾기 위해 위치 사용 권한이 필요해요",
            confirmText: "허용",
            cancelText: "취소",
            onConfirm: { store.send(.openAppSettings) },
            onCancel: { store.send(.dismissPermissionAlert) }
        )
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
                KFImage(photoBooth.brand.imageURL)
                    .resizable()
                    .placeholder {
                        ProgressView()
                    }
                    .onFailureImage(.imgDefaultBrandOriginal)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(photoBooth.brand.name)
                            .nekiFont(.title20SemiBold)
                            .foregroundStyle(.gray900)
                        
                        Text(photoBooth.name)
                            .nekiFont(.body14Medium)
                            .foregroundStyle(.gray600)
                    }
                    
                    Text(photoBooth.nearbyDistance?.distanceString ?? "")
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
            .contentShape(.rect)
            .onTapGesture { store.send(.didTapBoothCard) }
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
    
    var searchHereControl: some View {
        Button {
            store.send(.didTapSearchHereButton)
        } label: {
            HStack(spacing: 8) {
                Image(.iconRotate)
                
                Text("현 위치에서 탐색")
                    .nekiFont(.body14SemiBold)
                    .foregroundStyle(.gray800)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.white)
                    .strokeBorder(.gray100)
            )
        }
        .safeAreaPadding(.top)
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
