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
import QuartzCore

fileprivate enum Constants {
    // Map Settings
    static let defaultInitialPosition = NMGLatLng(lat: 37.498095, lng: 127.027610)
    static let animationDuration: TimeInterval = 0.4
    static let minZoomLevel: Double = 12.0
    static let maxZoomLevel: Double = 20.0
    static let initialZoomLevel: Double = 14.0
    
    // Marker Size
    static let normalSize = CGSize(width: 54, height: 62)
    static let selectedSize = CGSize(width: 72, height: 83)
    static let zIndexNormal: Int = 0
    static let zIndexSelected: Int = 100
    
    // Clustering Settings
    static let clusterMaxZoom: Int = 20
    static let clusterMinZoom: Int = 12
    static let clusterThresholdZoomIn: Double = 48.0
    static let clusterThresholdZoomOut: Double = 60.0
    static let leafCaptionTextSize: CGFloat = 12.0
    static let clusterCaptionTextSize: CGFloat = 14.0
    static let captionColorHex: UInt = 0x202227
    static let brandClusteringThreshold: Double = 14.0
    static let favoriteMarkerViewportUpdateInterval: TimeInterval = 0.15
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
        
        var lastCameraPosition: GeographicCoordinate?
        var isMapLoaded: Bool = false
        
        let parent: NaverMapRepresentable
        private var lastFavoriteMarkerViewportUpdateTime: TimeInterval = .zero
        
        private var markerImageTasks: [BoothID: Task<Void, Never>] = [:]
        private var overlayImageCache: NSCache<NSString, NMFOverlayImage> = {
            let cache = NSCache<NSString, NMFOverlayImage>()
            cache.countLimit = 30
            return cache
        }()
        private let defaultBrandImage: UIImage = UIImage(resource: .imgDefaultBrandOriginal)
        private lazy var defaultNormalOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(brandImage: defaultBrandImage, isSelected: false, isFavorite: false)
            return NMFOverlayImage(image: image)
        }()
        private lazy var defaultSelectedOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(brandImage: defaultBrandImage, isSelected: true, isFavorite: false)
            return NMFOverlayImage(image: image)
        }()
        private lazy var defaultFavoriteNormalOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(brandImage: defaultBrandImage, isSelected: false, isFavorite: true)
            return NMFOverlayImage(image: image)
        }()
        private lazy var defaultFavoriteSelectedOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(brandImage: defaultBrandImage, isSelected: true, isFavorite: true)
            return NMFOverlayImage(image: image)
        }()
        private var currentKeyByID: [BoothID: BoothClusteringKey] = [:]
        private var lastFavoriteByID: [BoothID: Bool] = [:]
        private var lastSelectedBoothID: BoothID?
        
        private var clusterer: NMCClusterer<BoothClusteringKey>?
        private let leafUpdater = BoothLeafMarkerUpdater()
        
        init(parent: NaverMapRepresentable) { self.parent = parent }
        
        private func setupClusterer(mapView: NMFMapView) {
            let builder = NMCComplexBuilder<BoothClusteringKey>()
            let clusterStrategy = ClusterStrategy()
            builder.markerManager = BoothMarkerManager()
            builder.leafMarkerUpdater = leafUpdater
            builder.clusterMarkerUpdater = BoothClusterMarkerUpdater(mapView: mapView)
            builder.maxClusteringZoom = Constants.clusterMaxZoom
            builder.minClusteringZoom = Constants.clusterMinZoom
            builder.maxScreenDistance = Constants.clusterThresholdZoomOut
            builder.thresholdStrategy = clusterStrategy
            builder.distanceStrategy = clusterStrategy
            builder.tagMergeStrategy = BoothTagMergeStrategy()
            
            let clusterer = builder.build()
            clusterer.mapView = mapView
            self.clusterer = clusterer
            
            leafUpdater.onLeafTapped = { [weak self] boothID in
                guard let booth = self?.parent.store.visiblePhotoBooths[id: boothID] else { return }
                self?.parent.store.send(.didTapBooth(booth))
            }
            
            leafUpdater.requestImage = { [weak self] booth, marker, isSelected in
                self?.loadMarkerImage(for: booth, marker: marker, isSelected: isSelected)
            }
        }
        
        private func loadMarkerImage(for booth: PhotoBooth, marker: NMFMarker, isSelected: Bool) {
            let cacheKey = createCacheKey(brandID: booth.brand.id, isSelected: isSelected, isFavorite: booth.isFavorite)

            if let cachedOverlay = overlayImageCache.object(forKey: cacheKey as NSString) {
                return applyOverlay(to: marker, overlay: cachedOverlay, expectedID: booth.id)
            }
            
            guard let url = booth.brand.imageURL else { return applyDefaultOverlay(to: marker, isSelected: isSelected, expectedID: booth.id) }
            
            markerImageTasks[booth.id]?.cancel()
            markerImageTasks[booth.id] = Task { [weak self, weak marker] in
                guard let self, let marker else { return }
                let resource = KF.ImageResource(downloadURL: url, cacheKey: url.absoluteString)
                
                do {
                    let result = try await KingfisherManager.shared.retrieveImage(with: resource)
                    guard Task.isCancelled == false else { return }
                    
                    let renderedOverlay: NMFOverlayImage? = await Task.detached(priority: .userInitiated) {
                        guard Task.isCancelled == false else { return nil }
                        let finalImage = MarkerImageRenderer.render(brandImage: result.image, isSelected: isSelected, isFavorite: booth.isFavorite)
                        return NMFOverlayImage(image: finalImage)
                    }.value
                    
                    guard let overlay = renderedOverlay, Task.isCancelled == false else { return }
                    
                    await MainActor.run {
                        self.overlayImageCache.setObject(overlay, forKey: cacheKey as NSString)
                        self.applyOverlay(to: marker, overlay: overlay, expectedID: booth.id)
                    }
                } catch {
                    guard Task.isCancelled == false else { return }
                    Logger.presentation.error("Brand Image Download Failed for Marker: \(booth.id) - \(error)")
                    await MainActor.run {
                        self.applyDefaultOverlay(to: marker, isSelected: isSelected, expectedID: booth.id)
                    }
                }
            }
        }
        
        func updateMarkers(
            mapView: NMFMapView,
            photoBooths: IdentifiedArrayOf<PhotoBooth>,
            selectedBoothID: BoothID?
        ) {
            if clusterer == nil { setupClusterer(mapView: mapView) }
            leafUpdater.updateState(photoBooths: photoBooths, selectedBoothID: selectedBoothID)
            
            let oldSelected = lastSelectedBoothID
            let selectionChanged = oldSelected != selectedBoothID
            
            var keysToAdd: [BoothClusteringKey: NSObject] = [:]
            var keysToRemove: [BoothClusteringKey] = []
            
            let newIDs = Set(photoBooths.ids)
            let toRemoveIDs = currentKeyByID.keys.filter { newIDs.contains($0) == false }
            keysToRemove.append(contentsOf: toRemoveIDs.compactMap { currentKeyByID[$0] })
            
            var coordinateFrequency = [String: Int]()
            
            for booth in photoBooths {
                let coordinateKey = "\(booth.coordinate.latitude), \(booth.coordinate.longitude)"
                let overlapIndex = coordinateFrequency[coordinateKey, default: .zero]
                coordinateFrequency[coordinateKey] = overlapIndex + 1
                let isNew = currentKeyByID.keys.contains(booth.id) == false
                let isSelectedAffected = selectionChanged && (booth.id == selectedBoothID || booth.id == oldSelected)
                let isFavoriteAffected = lastFavoriteByID[booth.id] != booth.isFavorite

                if isNew || isSelectedAffected || isFavoriteAffected {
                    let position = calculateJitteredPosition(latitude: booth.coordinate.latitude, longitude: booth.coordinate.longitude, overlapIndex: overlapIndex)
                    let key = BoothClusteringKey(identifier: booth.id, brandID: booth.brand.id, position: position)

                    if (isSelectedAffected || isFavoriteAffected), let oldKey = currentKeyByID[booth.id] { keysToRemove.append(oldKey) }
                    
                    keysToAdd[key] = NSNumber(value: booth.brand.id)
                    currentKeyByID[booth.id] = key
                }

                lastFavoriteByID[booth.id] = booth.isFavorite
            }
            
            if keysToRemove.isEmpty == false { clusterer?.removeAll(keysToRemove) }
            if keysToAdd.isEmpty == false { clusterer?.addAll(keysToAdd) }
            
            for id in toRemoveIDs {
                currentKeyByID.removeValue(forKey: id)
            }
            
            lastSelectedBoothID = selectedBoothID
        }
        
        func calculateJitteredPosition(latitude: Double, longitude: Double, overlapIndex: Int) -> NMGLatLng {
            guard overlapIndex > .zero else { return NMGLatLng(lat: latitude, lng: longitude) }
            
            let offsetRadius = 0.00005
            let angle = Double(overlapIndex) * (Double.pi / 3)
            let latitudeOffset = offsetRadius * cos(angle)
            let longitudeOffset = offsetRadius * sin(angle)
            return NMGLatLng(lat: latitude + latitudeOffset, lng: longitude + longitudeOffset)
        }
        
        func applyOverlay(to marker: NMFMarker, overlay: NMFOverlayImage, expectedID: Int) {
            guard let currentID = marker.userInfo["identifier"] as? Int, currentID == expectedID else { return }
            marker.iconImage = overlay
        }
        
        func applyDefaultOverlay(to marker: NMFMarker, isSelected: Bool, expectedID: Int) {
            guard let booth = parent.store.visiblePhotoBooths[id: expectedID] else { return }
            let targetOverlay: NMFOverlayImage

            switch (isSelected, booth.isFavorite) {
            case (true, true): targetOverlay = defaultFavoriteSelectedOverlay
            case (true, false): targetOverlay = defaultSelectedOverlay
            case (false, true): targetOverlay = defaultFavoriteNormalOverlay
            case (false, false): targetOverlay = defaultNormalOverlay
            }

            applyOverlay(to: marker, overlay: targetOverlay, expectedID: expectedID)
        }

        func createCacheKey(brandID: BrandID, isSelected: Bool, isFavorite: Bool) -> String {
            "brand_\(brandID)_selected_\(isSelected)_favorite_\(isFavorite)"
        }
    }
    
    final class ClusterStrategy: NMCDefaultDistanceStrategy, NMCThresholdStrategy {
        func getThreshold(_ zoom: Int) -> Double {
            guard Double(zoom) < Constants.brandClusteringThreshold else { return Constants.clusterThresholdZoomIn }
            return Constants.clusterThresholdZoomOut
        }
        
        override func getDistance(_ zoom: Int, node1: NMCNode, node2: NMCNode) -> Double {
            let defaultDistance = super.getDistance(zoom, node1: node1, node2: node2)
            
            if Double(zoom) < Constants.brandClusteringThreshold { return defaultDistance }
            
            guard let tag1 = node1.tag as? NSNumber,
                  let tag2 = node2.tag as? NSNumber,
                  tag1 == tag2
            else { return Double.infinity }
            
            return defaultDistance
        }
    }
    
    final class BoothClusteringKey: NSObject, NMCClusteringKey {
        let identifier: Int
        let brandID: Int
        let position: NMGLatLng
        
        init(identifier: Int, brandID: Int, position: NMGLatLng) {
            self.identifier = identifier
            self.brandID = brandID
            self.position = position
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Self else { return false }
            return self.identifier == other.identifier
        }
        
        override var hash: Int { identifier.hashValue }
        
        func copy(with zone: NSZone? = nil) -> Any {
            BoothClusteringKey(identifier: identifier, brandID: brandID, position: position)
        }
    }
    
    final class BoothLeafMarkerUpdater: NMCLeafMarkerUpdater {
        var onLeafTapped: ((Int) -> Void)?
        var requestImage: ((_ booth: PhotoBooth, _ marker: NMFMarker, _ isSelected: Bool) -> Void)?
        
        private var boothDataMap: [Int: PhotoBooth] = [:]
        private var selectedBoothID: Int?
        
        func updateState(photoBooths: IdentifiedArrayOf<PhotoBooth>, selectedBoothID: Int?) {
            boothDataMap = photoBooths.reduce(into: [:]) { $0[$1.id] = $1 }
            self.selectedBoothID = selectedBoothID
        }
        
        func updateLeafMarker(_ info: NMCLeafMarkerInfo, _ marker: NMFMarker) {
            guard let key = info.key as? BoothClusteringKey,
                  let booth = boothDataMap[key.identifier]
            else { return }
            
            let isSelected = (booth.id == selectedBoothID)
            marker.userInfo["identifier"] = booth.id
            marker.captionText = "\(booth.brand.name)\n\(booth.name)"
            marker.captionColor = .init(hex: Constants.captionColorHex)
            marker.captionHaloColor = .white
            marker.captionAligns = [NMFAlignType.bottom]
            marker.captionTextSize = 12
            marker.captionOffset = -8
            marker.anchor = CGPoint(x: 0.5, y: 1.0)
            marker.zIndex = isSelected ? Constants.zIndexSelected : Constants.zIndexNormal
            marker.touchHandler = { [weak self] _ in
                self?.onLeafTapped?(booth.id)
                return true
            }
            
            requestImage?(booth, marker, isSelected)
        }
    }
    
    final class BoothClusterMarkerUpdater: NMCDefaultClusterMarkerUpdater {
        private weak var mapView: NMFMapView?
        private var clusterImageCache: [String: NMFOverlayImage] = [:]
        
        init(mapView: NMFMapView) {
            self.mapView = mapView
            super.init()
        }
        
        override func updateClusterMarker(_ info: NMCClusterMarkerInfo, _ marker: NMFMarker) {
            guard let mapView else { return }
            let text = info.size > 50 ? "50+" : "\(info.size)"
            let currentZoom = mapView.zoomLevel
            
            var cacheKey = "default_\(text)"
            
            if currentZoom < Constants.brandClusteringThreshold {
                cacheKey = "default_\(text)"
            } else {
                // TODO: 이곳에서 브랜드별로 클러스터링된 이미지를 보여줄 수도 있습니다. 물론 지금은 디자인없음.
                // TODO: 태크 병합 전략 적용하여 어떤 브랜드끼리 클러스터링된 건지 표시할 수 있습니다.
                cacheKey = "default_\(text)"
            }
            
            let overlayImage: NMFOverlayImage
            if let cached = clusterImageCache[cacheKey] {
                overlayImage = cached
            } else {
                let rendered = ClusterMarkerRenderer.render(text)
                let overlay = NMFOverlayImage(image: rendered)
                clusterImageCache[cacheKey] = overlay
                overlayImage = overlay
            }
            
            marker.iconImage = overlayImage
            marker.captionText = ""
            marker.captionAligns = [NMFAlignType.center]
            marker.anchor = CGPoint(x: 0.5, y: 0.5)
            marker.zIndex = 50
            
            marker.touchHandler = { [weak mapView] overlay in
                guard let mapView, let marker = overlay as? NMFMarker else { return false }
                let currentZoom = mapView.zoomLevel
                let targetZoom = min(currentZoom + 2.5, Constants.maxZoomLevel)
                let cameraUpdate = NMFCameraUpdate(scrollTo: marker.position, zoomTo: targetZoom)
                cameraUpdate.animation = .easeOut
                cameraUpdate.animationDuration = Constants.animationDuration
                mapView.moveCamera(cameraUpdate)
                return true
            }
        }
    }
    
    final class BoothMarkerManager: NMCDefaultMarkerManager {
        override func createMarker() -> NMFMarker {
            let marker = super.createMarker()
            marker.isHideCollidedSymbols = true
            marker.isHideCollidedMarkers = false
            marker.isHideCollidedCaptions = false
            return marker
        }
    }
    
    final class BoothTagMergeStrategy: NSObject, NMCTagMergeStrategy {
        func mergeTag(_ cluster: NMCCluster) -> NSObject? {
            var mergedBrandID: Int?
            
            for node in cluster.children {
                guard let tag = node.tag as? NSNumber else { return nil }
                let currentBrandID = tag.intValue
                
                if mergedBrandID == nil {
                    mergedBrandID = currentBrandID
                } else if mergedBrandID != currentBrandID {
                    return nil
                }
            }
            
            return mergedBrandID.map { NSNumber(value: $0) }
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

    func mapView(_ mapView: NMFMapView, cameraIsChangingByReason reason: Int) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastFavoriteMarkerViewportUpdateTime >= Constants.favoriteMarkerViewportUpdateInterval else { return }
        lastFavoriteMarkerViewportUpdateTime = currentTime
        parent.store.send(.cameraMotionChanged(mapView.contentBounds.toDomain()))
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
        parent.store.send(.didTapCloseDetail, animation: .default)
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
            DirectionAppsSheet(store: store, photoBooth: photoBooth)
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
            mapControllers()
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
            mapControllers(selectedBooth: photoBooth)
            
            HStack(spacing: 12) {
                KFImage(photoBooth.brand.imageURL)
                    .resizable()
                    .placeholder {
                        ProgressView()
                    }
                    .onFailureImage(.imgDefaultBrandOriginal)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(photoBooth.brand.name)
                        .nekiFont(.title20SemiBold)
                        .foregroundStyle(.gray900)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(photoBooth.name)
                            .nekiFont(.body14Medium)
                            .foregroundStyle(.gray600)
                            .lineLimit(1)
                        
                        Rectangle()
                            .frame(width: 1, height: 10)
                            .foregroundStyle(.gray100)
                        
                        Text(photoBooth.nearbyDistance?.distanceString ?? "")
                            .nekiFont(.body14SemiBold)
                            .foregroundStyle(.gray700)
                    }
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
    
    func mapControllers(selectedBooth: PhotoBooth? = nil) -> some View {
        HStack {
            VStack(spacing: 8) {
                if let selectedBooth {
                    favoriteControlButton(
                        isSelected: selectedBooth.isFavorite,
                        action: { store.send(.didTapFavorite(selectedBooth)) }
                    )
                } else {
                    favoriteControlButton(
                        isSelected: store.isFavoriteMarkerFilterEnabled,
                        action: { store.send(.didTapFavoriteMarkerFilterButton) }
                    )
                    
                    Button {
                        store.send(.didTapCurrentLocationButton)
                    } label: {
                        Image(store.isUserTrackingMode ? .iconCurrentLocationActive : .iconCurrentLocationInactive)
                            .padding(8)
                            .background(.white)
                            .clipShape(.circle)
                    }
                }
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
    
    func favoriteControlButton(isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(isSelected ? .iconHeart28Fill : .iconHeart28Gray)
                .padding(8)
                .background(.white)
                .clipShape(.circle)
        }
    }
    
    var searchHereControl: some View {
        Button {
            store.send(.didTapSearchHereButton)
        } label: {
            HStack(spacing: 7) {
                Image(.iconRotate)
                
                Text("이 지역 재검색")
                    .nekiFont(.body14SemiBold)
                    .foregroundStyle(.gray800)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            )
            .overlay {
                Capsule()
                    .strokeBorder(.primary400)
            }
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
