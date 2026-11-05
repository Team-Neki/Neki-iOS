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
    /// 영역에 카메라를 맞출 때 가장자리에 남길 여백
    static let fitBoundsPadding: CGFloat = 40
    /// 영역에 카메라를 맞출 때 보장할 최소 크기(위경도). 약 220m에 해당합니다.
    static let minimumFitSpan: Double = 0.002
    
    // Marker Presentation
    static let zIndexNormal: Int = 0
    static let zIndexSelected: Int = 100
    
    // Clustering Settings
    static let clusterMaxZoom: Int = 19
    static let clusterMinZoom: Int = 12
    static let clusterThresholdZoomIn: Double = 48.0
    static let clusterThresholdZoomOut: Double = 60.0
    static let leafCaptionTextSize: CGFloat = 12.0
    static let clusterCaptionTextSize: CGFloat = 14.0
    static let captionColorHex: UInt = 0x202227
    static let brandClusteringThreshold: Double = 14.0
    /// 이 줌까지 가까운 POI의 SDK 클러스터링을 유지합니다.
    static let overlappingMarkerExpansionZoom: Int = 18
    /// 최대 줌에서 마커 간격이 과도하게 확대되지 않도록 고정 지리 좌표를 계산합니다.
    static let overlappingMarkerLayoutZoom = maxZoomLevel
    /// 최대 줌에서 서로 다른 마커를 터치할 수 있도록 확보할 최소 중심 간격입니다.
    static let overlappingMarkerSeparationSize = CGSize(width: 44, height: 44)
    /// 이 거리 이내의 가까운 좌표를 같은 위치로 취급합니다.
    static let overlappingMarkerMaximumDistanceMeters: Double = 1
    static let favoriteMarkerViewportUpdateInterval: TimeInterval = 0.15
    
    // Search Field
    /// 지도 상단 검색 필드를 상단 안전 영역에서 띄우는 높이
    static let searchFieldTopPadding: CGFloat = 8
    /// 시트를 가장 높이 올렸을 때 검색 필드 아래에 둘 간격
    static let sheetSpacingBelowSearchField: CGFloat = 8
}

struct NaverMapRepresentable: UIViewRepresentable {
    @Environment(\.displayScale) private var displayScale

    @Bindable var store: StoreOf<MapFeature>
    let isLocationAuthorized: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, displayScale: displayScale)
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
        let hasPendingCameraUpdate = context.coordinator.hasPendingCameraMove(store.cameraMoveRequest)
            || context.coordinator.hasPendingCameraFit(store.cameraFitRequest)

        // 시트가 사라지는 동시에 카메라를 옮기면, 기존 inset을 기준으로 이동을 시작한 뒤
        // inset 애니메이션이 지도의 유효 중심을 다시 바꾸게 된다. 새 카메라 요청은 목표 inset을 먼저 확정한다.
        updateContentInset(
            uiView.mapView,
            animated: hasPendingCameraUpdate == false
        )

        // State 변경 시 카메라 이동
        if context.coordinator.isMapLoaded {
            updateCameraPosition(uiView.mapView, context: context)
            updateCameraFitBounds(uiView.mapView, context: context)
        }
        
        // 마커 업데이트
        context.coordinator.updateMarkers(
            mapView: uiView.mapView,
            photoBooths: store.visiblePhotoBooths,
            selectedBoothID: store.selectedBooth?.id
        )
        
        // 현위치 모드는 인셋을 반영한 뒤에 맞춥니다. 인셋을 바꾸면 SDK가 위치 추적 모드를 풀어 버리기 때문입니다.
        updateLocationOverlay(uiView.mapView, isAuthorized: isLocationAuthorized)
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
    
    /// 카메라를 한 지점으로 옮깁니다.
    ///
    /// 마커나 시트 갱신처럼 카메라와 무관한 이유로도 이 메서드가 다시 불리므로,
    /// 이미 반영한 요청인지 세대로 가려내 같은 요청을 거듭 적용하지 않습니다.
    func updateCameraPosition(_ mapView: NMFMapView, context: Context) {
        let request = store.cameraMoveRequest
        guard let coordinate = request.coordinate,
              request.generation != context.coordinator.appliedCameraMoveGeneration
        else { return }
        context.coordinator.appliedCameraMoveGeneration = request.generation

        let cameraUpdate = NMFCameraUpdate(scrollTo: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude))
        cameraUpdate.animation = .easeOut
        cameraUpdate.animationDuration = Constants.animationDuration
        mapView.moveCamera(cameraUpdate)
    }

    /// 여러 지점을 한 화면에 담도록 카메라를 영역에 맞춥니다.
    ///
    /// 지점이 하나뿐이거나 몰려 있으면 영역이 한 점에 가까워 최대 배율까지 당겨지므로,
    /// 최소 크기만큼 넓혀 적당한 배율을 유지합니다.
    ///
    /// 마커나 시트 갱신처럼 카메라와 무관한 이유로도 이 메서드가 다시 불리므로,
    /// 이미 반영한 요청인지 세대로 가려내 같은 요청을 거듭 적용하지 않습니다.
    func updateCameraFitBounds(_ mapView: NMFMapView, context: Context) {
        let request = store.cameraFitRequest
        guard let bounds = request.bounds,
              request.generation != context.coordinator.appliedCameraFitGeneration
        else { return }
        context.coordinator.appliedCameraFitGeneration = request.generation

        let latitudePadding = max(Constants.minimumFitSpan - (bounds.maxLatitude - bounds.minLatitude), .zero) / 2
        let longitudePadding = max(Constants.minimumFitSpan - (bounds.maxLongitude - bounds.minLongitude), .zero) / 2
        let latLngBounds = NMGLatLngBounds(
            southWestLat: bounds.minLatitude - latitudePadding,
            southWestLng: bounds.minLongitude - longitudePadding,
            northEastLat: bounds.maxLatitude + latitudePadding,
            northEastLng: bounds.maxLongitude + longitudePadding
        )
        let cameraUpdate = NMFCameraUpdate(fit: latLngBounds, padding: Constants.fitBoundsPadding)
        cameraUpdate.animation = .easeOut
        cameraUpdate.animationDuration = Constants.animationDuration
        mapView.moveCamera(cameraUpdate)
    }

    func updateContentInset(_ mapView: NMFMapView, animated: Bool) {
        let sheetHeight = store.detent.resolve(in: UIScreen.main.bounds.height, inset: .screenTabBarHeight)
        let targetInset = store.detent == .large ? .zero : UIEdgeInsets(top: .zero, left: .zero, bottom: sheetHeight, right: .zero)
        guard mapView.contentInset != targetInset else { return }

        if animated {
            UIView.animate(
                withDuration: Constants.animationDuration,
                delay: .zero,
                options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction]
            ) {
                mapView.contentInset = targetInset
                mapView.layoutIfNeeded()
            }
        } else {
            UIView.performWithoutAnimation {
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
        typealias BoothID = PhotoBooth.ID
        typealias BrandID = Int

        var appliedCameraMoveGeneration: UInt?
        var appliedCameraFitGeneration: UInt?
        var isMapLoaded: Bool = false
        
        let parent: NaverMapRepresentable
        private let displayScale: CGFloat
        private var lastFavoriteMarkerViewportUpdateTime: TimeInterval = .zero
        
        private var markerImageTasks: [BoothID: Task<Void, Never>] = [:]
        private var markerImageRequestIDs: [BoothID: UUID] = [:]
        private var overlayImageCache: NSCache<NSString, NMFOverlayImage> = {
            let cache = NSCache<NSString, NMFOverlayImage>()
            cache.countLimit = 30
            return cache
        }()
        private let defaultBrandImage: UIImage = UIImage(resource: .imgDefaultBrandOriginal)
        private lazy var defaultNormalOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(
                brandImage: defaultBrandImage,
                isSelected: false,
                isFavorite: false,
                displayScale: displayScale
            )
            return NMFOverlayImage(image: image)
        }()
        private lazy var defaultSelectedOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(
                brandImage: defaultBrandImage,
                isSelected: true,
                isFavorite: false,
                displayScale: displayScale
            )
            return NMFOverlayImage(image: image)
        }()
        private lazy var defaultFavoriteNormalOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(
                brandImage: defaultBrandImage,
                isSelected: false,
                isFavorite: true,
                displayScale: displayScale
            )
            return NMFOverlayImage(image: image)
        }()
        private lazy var defaultFavoriteSelectedOverlay: NMFOverlayImage = {
            let image = MarkerImageRenderer.render(
                brandImage: defaultBrandImage,
                isSelected: true,
                isFavorite: true,
                displayScale: displayScale
            )
            return NMFOverlayImage(image: image)
        }()

        private var currentKeyByID: [BoothID: BoothClusteringKey] = [:]
        private var clusteredMarkerStateByID: [BoothID: PhotoBoothMarkerPresentationState] = [:]
        private var visibleBoothIDs: Set<BoothID> = []
        private var lastRenderedMarkerStatesByID: [BoothID: PhotoBoothMarkerPresentationState]?
        private var lastSelectedBoothID: BoothID?
        
        private var clusterer: NMCClusterer<BoothClusteringKey>?
        private let leafUpdater = BoothLeafMarkerUpdater()
        
        init(parent: NaverMapRepresentable, displayScale: CGFloat) {
            self.parent = parent
            self.displayScale = displayScale
        }

        func hasPendingCameraMove(_ request: MapFeature.CameraMoveRequest) -> Bool {
            request.coordinate != nil && request.generation != appliedCameraMoveGeneration
        }

        func hasPendingCameraFit(_ request: MapFeature.CameraFitRequest) -> Bool {
            request.bounds != nil && request.generation != appliedCameraFitGeneration
        }
        
        private func setupClusterer(mapView: NMFMapView) {
            let builder = NMCComplexBuilder<BoothClusteringKey>()
            let clusterStrategy = ClusterStrategy()
            builder.leafMarkerUpdater = leafUpdater
            builder.clusterMarkerUpdater = BoothClusterMarkerUpdater(mapView: mapView)
            builder.maxClusteringZoom = Constants.clusterMaxZoom
            builder.minClusteringZoom = Constants.clusterMinZoom
            builder.maxScreenDistance = Constants.clusterThresholdZoomOut
            builder.animationDuration = Constants.animationDuration
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
            markerImageTasks.removeValue(forKey: booth.id)?.cancel()
            markerImageRequestIDs.removeValue(forKey: booth.id)

            let cacheKey = createCacheKey(
                brandID: booth.brand.id,
                imageURL: booth.brand.imageURL,
                isSelected: isSelected,
                isFavorite: booth.isFavorite
            )

            if let cachedOverlay = overlayImageCache.object(forKey: cacheKey as NSString) {
                return applyOverlay(to: marker, overlay: cachedOverlay, expectedID: booth.id)
            }
            
            guard let url = booth.brand.imageURL else { return applyDefaultOverlay(to: marker, isSelected: isSelected, expectedID: booth.id) }

            let requestID = UUID()
            markerImageRequestIDs[booth.id] = requestID
            markerImageTasks[booth.id] = Task { [weak self, weak marker] in
                guard let self, let marker else { return }
                defer { finishMarkerImageRequest(for: booth.id, requestID: requestID) }
                let resource = KF.ImageResource(downloadURL: url, cacheKey: url.absoluteString)
                
                do {
                    let result = try await KingfisherManager.shared.retrieveImage(with: resource)
                    guard Task.isCancelled == false else { return }
                    let displayScale = self.displayScale
                    
                    let renderedOverlay: NMFOverlayImage? = await Task.detached(priority: .userInitiated) {
                        guard Task.isCancelled == false else { return nil }
                        let finalImage = MarkerImageRenderer.render(
                            brandImage: result.image,
                            isSelected: isSelected,
                            isFavorite: booth.isFavorite,
                            displayScale: displayScale
                        )
                        return NMFOverlayImage(image: finalImage)
                    }.value
                    
                    guard let overlay = renderedOverlay, Task.isCancelled == false else { return }
                    
                    await MainActor.run {
                        guard self.markerImageRequestIDs[booth.id] == requestID else { return }
                        self.overlayImageCache.setObject(overlay, forKey: cacheKey as NSString)
                        self.applyOverlay(to: marker, overlay: overlay, expectedID: booth.id)
                    }
                } catch {
                    guard Task.isCancelled == false else { return }
                    Logger.presentation.error("Brand Image Download Failed for Marker: \(booth.id) - \(error)")
                    await MainActor.run {
                        guard self.markerImageRequestIDs[booth.id] == requestID else { return }
                        self.applyDefaultOverlay(to: marker, isSelected: isSelected, expectedID: booth.id)
                    }
                }
            }
        }

        private func finishMarkerImageRequest(for boothID: BoothID, requestID: UUID) {
            guard markerImageRequestIDs[boothID] == requestID else { return }
            markerImageRequestIDs.removeValue(forKey: boothID)
            markerImageTasks.removeValue(forKey: boothID)
        }
        
        func updateMarkers(
            mapView: NMFMapView,
            photoBooths: IdentifiedArrayOf<PhotoBooth>,
            selectedBoothID: BoothID?
        ) {
            if clusterer == nil { setupClusterer(mapView: mapView) }

            let markerStatesByID = photoBooths.reduce(into: [BoothID: PhotoBoothMarkerPresentationState]()) {
                $0[$1.id] = PhotoBoothMarkerPresentationState(booth: $1)
            }
            guard lastRenderedMarkerStatesByID != markerStatesByID
                    || lastSelectedBoothID != selectedBoothID
            else { return }
            lastRenderedMarkerStatesByID = markerStatesByID
            leafUpdater.updateState(photoBooths: photoBooths, selectedBoothID: selectedBoothID)

            let newOverlappingGroups = OverlappingMarkerGroupResolver.groups(
                elements: photoBooths,
                id: \.id,
                coordinate: \.coordinate,
                maximumDistanceMeters: Constants.overlappingMarkerMaximumDistanceMeters
            )
            let markerPositions = makeMarkerPositions(
                photoBooths: photoBooths,
                overlappingGroups: newOverlappingGroups
            )
            let markerTags = makeMarkerTags(
                photoBooths: photoBooths,
                overlappingGroups: newOverlappingGroups
            )
            let allIDs = Set(photoBooths.ids)

            updateClusteredMarkers(
                photoBooths: photoBooths,
                markerPositions: markerPositions,
                markerTags: markerTags,
                selectedBoothID: selectedBoothID
            )

            for id in visibleBoothIDs.subtracting(allIDs) {
                markerImageTasks.removeValue(forKey: id)?.cancel()
                markerImageRequestIDs.removeValue(forKey: id)
            }
            visibleBoothIDs = allIDs
            lastSelectedBoothID = selectedBoothID
        }

        private func updateClusteredMarkers(
            photoBooths: IdentifiedArrayOf<PhotoBooth>,
            markerPositions: [BoothID: NMGLatLng],
            markerTags: [BoothID: BoothClusterTag],
            selectedBoothID: BoothID?
        ) {
            let photoBoothIDs = Set(photoBooths.ids)
            let removedIDs = currentKeyByID.keys.filter { photoBoothIDs.contains($0) == false }
            var keysToRemove = removedIDs.compactMap { currentKeyByID[$0] }
            var keysToAdd: [BoothClusteringKey: NSObject] = [:]
            let selectionChanged = lastSelectedBoothID != selectedBoothID

            for booth in photoBooths {
                let position = markerPositions[booth.id]
                    ?? NMGLatLng(lat: booth.coordinate.latitude, lng: booth.coordinate.longitude)
                let tag = markerTags[booth.id] ?? BoothClusterTag(brandID: booth.brand.id)
                let state = PhotoBoothMarkerPresentationState(booth: booth)
                let markerChanged = clusteredMarkerStateByID[booth.id] != state
                let selectionAffectsMarker = selectionChanged
                    && (booth.id == selectedBoothID || booth.id == lastSelectedBoothID)
                let registrationChanged = currentKeyByID[booth.id]?.matches(position: position, tag: tag) != true
                guard registrationChanged || markerChanged || selectionAffectsMarker else { continue }

                if let oldKey = currentKeyByID[booth.id] {
                    keysToRemove.append(oldKey)
                }
                let key = BoothClusteringKey(identifier: booth.id, position: position, tag: tag)
                keysToAdd[key] = tag
                currentKeyByID[booth.id] = key
                clusteredMarkerStateByID[booth.id] = state
            }

            if keysToRemove.isEmpty == false { clusterer?.removeAll(keysToRemove) }
            if keysToAdd.isEmpty == false { clusterer?.addAll(keysToAdd) }
            for id in removedIDs {
                currentKeyByID.removeValue(forKey: id)
                clusteredMarkerStateByID.removeValue(forKey: id)
            }
        }

        private func makeMarkerPositions(
            photoBooths: IdentifiedArrayOf<PhotoBooth>,
            overlappingGroups: [GeographicCoordinate: [BoothID]]
        ) -> [BoothID: NMGLatLng] {
            var positions = photoBooths.reduce(into: [BoothID: NMGLatLng]()) { result, booth in
                result[booth.id] = NMGLatLng(
                    lat: booth.coordinate.latitude,
                    lng: booth.coordinate.longitude
                )
            }

            for (origin, boothIDs) in overlappingGroups {
                let coordinates = OverlappingMarkerLayout.coordinates(
                    origin: origin,
                    count: boothIDs.count,
                    markerSize: Constants.overlappingMarkerSeparationSize,
                    minimumGap: .zero,
                    zoomLevel: Constants.overlappingMarkerLayoutZoom
                )
                for (boothID, coordinate) in zip(boothIDs, coordinates) {
                    positions[boothID] = NMGLatLng(
                        lat: coordinate.latitude,
                        lng: coordinate.longitude
                    )
                }
            }
            return positions
        }

        private func makeMarkerTags(
            photoBooths: IdentifiedArrayOf<PhotoBooth>,
            overlappingGroups: [GeographicCoordinate: [BoothID]]
        ) -> [BoothID: BoothClusterTag] {
            var tags = photoBooths.reduce(into: [BoothID: BoothClusterTag]()) { result, booth in
                result[booth.id] = BoothClusterTag(brandID: booth.brand.id)
            }

            for boothIDs in overlappingGroups.values {
                for boothID in boothIDs {
                    guard let tag = tags[boothID] else { continue }
                    tags[boothID] = BoothClusterTag(
                        brandID: tag.brandID,
                        overlappingGroupID: boothIDs
                    )
                }
            }
            return tags
        }
        
        func applyOverlay(to marker: NMFMarker, overlay: NMFOverlayImage, expectedID: BoothID) {
            guard let currentID = marker.userInfo["identifier"] as? BoothID, currentID == expectedID else { return }
            marker.iconImage = overlay
        }
        
        func applyDefaultOverlay(to marker: NMFMarker, isSelected: Bool, expectedID: BoothID) {
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

        func createCacheKey(brandID: BrandID, imageURL: URL?, isSelected: Bool, isFavorite: Bool) -> String {
            "brand_\(brandID)_url_\(imageURL?.absoluteString ?? "nil")_selected_\(isSelected)_favorite_\(isFavorite)"
        }
    }
    
    final class ClusterStrategy: NMCDefaultDistanceStrategy, NMCThresholdStrategy {
        func getThreshold(_ zoom: Int) -> Double {
            guard Double(zoom) < Constants.brandClusteringThreshold else { return Constants.clusterThresholdZoomIn }
            return Constants.clusterThresholdZoomOut
        }

        static func shouldUseDefaultDistance(
            zoom: Int,
            firstTag: NSObject?,
            secondTag: NSObject?
        ) -> Bool {
            if Double(zoom) < Constants.brandClusteringThreshold { return true }
            guard let firstTag = firstTag as? BoothClusterTag,
                  let secondTag = secondTag as? BoothClusterTag
            else { return false }
            let sharesOverlappingGroup = firstTag.overlappingGroupID != nil
                && firstTag.overlappingGroupID == secondTag.overlappingGroupID
            let sharesBrand = firstTag.brandID != nil && firstTag.brandID == secondTag.brandID
            if sharesOverlappingGroup {
                return zoom <= Constants.overlappingMarkerExpansionZoom
            }
            return sharesBrand
        }
        
        override func getDistance(_ zoom: Int, node1: NMCNode, node2: NMCNode) -> Double {
            let defaultDistance = super.getDistance(zoom, node1: node1, node2: node2)
            return Self.shouldUseDefaultDistance(
                zoom: zoom,
                firstTag: node1.tag,
                secondTag: node2.tag
            ) ? defaultDistance : .infinity
        }
    }

    final class BoothClusterTag: NSObject {
        let brandID: PhotoBoothBrand.ID?
        let overlappingGroupID: [PhotoBooth.ID]?

        init(
            brandID: PhotoBoothBrand.ID?,
            overlappingGroupID: [PhotoBooth.ID]? = nil
        ) {
            self.brandID = brandID
            self.overlappingGroupID = overlappingGroupID
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? BoothClusterTag else { return false }
            if let brandID, let otherBrandID = other.brandID {
                return brandID == otherBrandID
            }
            return overlappingGroupID != nil && overlappingGroupID == other.overlappingGroupID
        }

        override var hash: Int {
            var hasher = Hasher()
            if let brandID {
                hasher.combine(brandID)
            } else {
                hasher.combine(overlappingGroupID)
            }
            return hasher.finalize()
        }
    }

    final class BoothClusteringKey: NSObject, NMCClusteringKey {
        let identifier: PhotoBooth.ID
        let position: NMGLatLng
        let tag: BoothClusterTag

        init(identifier: PhotoBooth.ID, position: NMGLatLng, tag: BoothClusterTag) {
            self.identifier = identifier
            self.position = position
            self.tag = tag
        }

        func matches(position: NMGLatLng, tag: BoothClusterTag) -> Bool {
            self.position.lat == position.lat
                && self.position.lng == position.lng
                && self.tag.brandID == tag.brandID
                && self.tag.overlappingGroupID == tag.overlappingGroupID
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Self else { return false }
            return self.identifier == other.identifier
        }
        
        override var hash: Int { identifier.hashValue }
        
        func copy(with zone: NSZone? = nil) -> Any {
            BoothClusteringKey(identifier: identifier, position: position, tag: tag)
        }
    }
    
    final class BoothLeafMarkerUpdater: NMCLeafMarkerUpdater {
        var onLeafTapped: ((PhotoBooth.ID) -> Void)?
        var requestImage: ((_ booth: PhotoBooth, _ marker: NMFMarker, _ isSelected: Bool) -> Void)?
        
        private var boothDataMap: [PhotoBooth.ID: PhotoBooth] = [:]
        private var selectedBoothID: PhotoBooth.ID?
        
        func updateState(photoBooths: IdentifiedArrayOf<PhotoBooth>, selectedBoothID: PhotoBooth.ID?) {
            boothDataMap = photoBooths.reduce(into: [:]) { $0[$1.id] = $1 }
            self.selectedBoothID = selectedBoothID
        }
        
        func updateLeafMarker(_ info: NMCLeafMarkerInfo, _ marker: NMFMarker) {
            guard let key = info.key as? BoothClusteringKey,
                  let booth = boothDataMap[key.identifier]
            else { return }
            
            let isSelected = (booth.id == selectedBoothID)
            PhotoBoothMarkerConfigurator.configure(
                marker,
                for: booth,
                isSelected: isSelected,
                style: PhotoBoothMarkerStyle(
                    captionColorHex: Constants.captionColorHex,
                    captionTextSize: Constants.leafCaptionTextSize,
                    normalZIndex: Constants.zIndexNormal,
                    selectedZIndex: Constants.zIndexSelected
                )
            )
            marker.touchHandler = { [weak self] _ in
                self?.onLeafTapped?(booth.id)
                return true
            }
            
            requestImage?(booth, marker, isSelected)
        }
    }
    
    final class BoothClusterMarkerUpdater: NMCDefaultClusterMarkerUpdater {
        private weak var mapView: NMFMapView?
        private let clusterImageCache: NSCache<NSString, NMFOverlayImage> = {
            let cache = NSCache<NSString, NMFOverlayImage>()
            cache.countLimit = 10
            return cache
        }()
        
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
            if let cached = clusterImageCache.object(forKey: cacheKey as NSString) {
                overlayImage = cached
            } else {
                let rendered = ClusterMarkerRenderer.render(text)
                let overlay = NMFOverlayImage(image: rendered)
                clusterImageCache.setObject(overlay, forKey: cacheKey as NSString)
                overlayImage = overlay
            }
            
            marker.iconImage = overlayImage
            marker.userInfo = [:]
            marker.captionText = ""
            marker.captionColor = .black
            marker.captionHaloColor = .white
            marker.captionAligns = [NMFAlignType.center]
            marker.captionTextSize = Constants.leafCaptionTextSize
            marker.captionOffset = 0
            marker.anchor = CGPoint(x: 0.5, y: 0.5)
            marker.zIndex = 50
            marker.isHideCollidedSymbols = true
            marker.isHideCollidedMarkers = false
            marker.isHideCollidedCaptions = false
            marker.isForceShowCaption = false
            
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
    
    final class BoothTagMergeStrategy: NSObject, NMCTagMergeStrategy {
        func mergeTag(_ cluster: NMCCluster) -> NSObject? {
            var mergedBrandID: PhotoBoothBrand.ID?
            var mergedOverlappingGroupID: [PhotoBooth.ID]?
            var hasMergedTag = false

            for node in cluster.children {
                guard let tag = node.tag as? BoothClusterTag else { return nil }
                if hasMergedTag {
                    if mergedBrandID != tag.brandID { mergedBrandID = nil }
                    if mergedOverlappingGroupID != tag.overlappingGroupID {
                        mergedOverlappingGroupID = nil
                    }
                } else {
                    mergedBrandID = tag.brandID
                    mergedOverlappingGroupID = tag.overlappingGroupID
                    hasMergedTag = true
                }
            }

            guard hasMergedTag,
                  mergedBrandID != nil || mergedOverlappingGroupID != nil
            else { return nil }
            return BoothClusterTag(
                brandID: mergedBrandID,
                overlappingGroupID: mergedOverlappingGroupID
            )
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
        guard reason == NMFMapChangedByGesture else { return }

        let currentTime = CACurrentMediaTime()
        if currentTime - lastFavoriteMarkerViewportUpdateTime >= Constants.favoriteMarkerViewportUpdateInterval {
            lastFavoriteMarkerViewportUpdateTime = currentTime
            parent.store.send(.cameraMotionChanged(mapView.contentBounds.toDomain(), zoomLevel: mapView.zoomLevel))
        }
    }
    
    func mapViewCameraIdle(_ mapView: NMFMapView) {
        let nmapBounds = mapView.contentBounds
        let geographicBounds = nmapBounds.toDomain()
        let zoomLevel = mapView.zoomLevel
        if isMapLoaded == false {
            isMapLoaded = true
            parent.store.send(.mapLoaded(geographicBounds, zoomLevel: zoomLevel))
        }
        parent.store.send(.cameraMotionEnded(geographicBounds, zoomLevel: zoomLevel))
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
    /// 지도 상단 검색 필드의 높이입니다. 시트를 가장 높이 올려도 검색 필드를 가리지 않도록 잽니다.
    @State private var searchFieldHeight: CGFloat = .zero
    
    @Dependency(\.distanceFormatterClient) var formatterClient
    
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
            VStack(spacing: 12) {
                MapSearchField(store: store)
                    .padding(.horizontal, 20)
                    .measureHeight { searchFieldHeight = $0 }

                if store.isExploreHereButtonVisible {
                    exploreHereControl
                }
            }
            .safeAreaPadding(.top, Constants.searchFieldTopPadding)
        }
        .nekiSheet(selection: $store.detent) {
            NearPhotoBoothListSheet(store: store.scope(state: \.photoBoothListState, action: \.photoBoothListAction))
                .scrollDisabled(store.detent != .large)
        } controllers: {
            mapControllers()
        }
        // 시트를 가장 높이 올려도 검색 필드는 가리지 않고 그 아래에서 멈춥니다.
        .nekiSheetTopInset(Constants.searchFieldTopPadding + searchFieldHeight + Constants.sheetSpacingBelowSearchField)
        .nekiSheetBottomInset()
        .nekiSheetDetents(store.sheetDetents)
        .animation(.easeOut(duration: Constants.animationDuration), value: store.detent)
        .animation(.easeOut(duration: Constants.animationDuration), value: store.selectedBooth?.id)
        // 검색 화면은 지도 화면의 검색 모드라 새 화면으로 띄우지 않고 지도 위에 겹쳐 그립니다.
        // 시트·버튼보다 위, 알림보다 아래에 그려지도록 이 자리에 둡니다.
        // 검색 중 키보드가 올라와도 지도 크기가 바뀌지 않도록 지도 쪽은 키보드 영역을 무시하고,
        // 가려진 지도는 VoiceOver가 읽지 않게 합니다.
        .ignoresSafeArea(.keyboard)
        .accessibilityHidden(store.isSearchPresented)
        .overlay {
            if store.isSearchPresented {
                PhotoBoothSearchView(
                    store: store.scope(state: \.photoBoothSearchState, action: \.photoBoothSearchAction)
                )
                // 결과를 고르는 순간처럼 지도 쪽 애니메이션이 섞여도 검색 화면은 전환 없이 바로 바뀝니다.
                .transition(.identity)
            }
        }
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
        VStack(spacing: 8) {
            mapControllers(selectedBooth: photoBooth)
            
            HStack(spacing: 12) {
                KFImage(photoBooth.brand.imageURL)
                    .resizable()
                    .placeholder {
                        ProgressView()
                    }
                    .onFailureImage(.imgDefaultBrandOriginal)
                    .frame(width: 70, height: 70)
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
                        
                        // 위치를 모른 채 검색한 결과처럼 거리를 표기하지 않을 때는 구분선도 함께 뺍니다.
                        if store.isSelectedBoothDistanceVisible, let distance = photoBooth.nearbyDistance {
                            Rectangle()
                                .frame(width: 1, height: 10)
                                .foregroundStyle(.gray100)
                            
                            Text(formatterClient.string(distance: distance))
                                .nekiFont(.body14SemiBold)
                                .foregroundStyle(.gray700)
                        }
                    }
                }
                
                Spacer()

                VStack(spacing: 6) {
                    Button {
                        store.send(.didTapFavorite(photoBooth))
                    } label: {
                        Image(photoBooth.isFavorite ? .iconFavoriteHeartFill : .iconFavoriteHeart)
                            .padding(5)
                            .background { Circle().fill(.gray25) }
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.send(.didTapDirectionAppsButton)
                    } label: {
                        Image(.iconDirections)
                    }
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
                if selectedBooth == nil {
                    let favoriteButton = favoriteControlButton(
                        isSelected: store.isFavoriteMarkerFilterEnabled,
                        action: { store.send(.didTapFavoriteMarkerFilterButton) }
                    )
                    // 검색 결과를 보는 동안에는 숨기되 자리는 남깁니다.
                    // 시트는 버튼 묶음의 높이를 재서 위치를 정하므로, 검색을 시작하고 끝낼 때 그 높이가 바뀌지 않게 합니다.
                    if store.isFavoriteMarkerFilterButtonVisible {
                        favoriteButton
                    } else {
                        favoriteButton.hidden()
                    }
                    
                    Button {
                        store.send(.didTapCurrentLocationButton)
                    } label: {
                        // 비활성 아이콘은 28pt 아이콘 영역 가운데에 놓이는 그림만 담고 있어, 활성 아이콘과 같은 영역에 맞춥니다.
                        Image(store.isUserTrackingMode ? .iconCurrentLocationActive : .iconCurrentLocationInactive)
                            .frame(width: 28, height: 28)
                            .padding(6)
                            .background(.white)
                            .clipShape(.circle)
                            // 버튼은 자기 프레임 안의 터치만 받으므로, 누르는 영역을 44pt로 맞추려고 프레임을 키웁니다.
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    // 키운 만큼 바깥 여백을 2pt씩 빼서, 버튼 묶음에서는 보이는 원(40pt) 크기만 차지하게 합니다.
                    .padding(-2)
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
        .nekiShadow(.button)
    }
    
    func favoriteControlButton(isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(isSelected ? .iconHeart28Fill : .iconMapButtonHeart)
                .padding(6)
                .background(.white)
                .clipShape(.circle)
                // 버튼은 자기 프레임 안의 터치만 받으므로, 누르는 영역을 44pt로 맞추려고 프레임을 키웁니다.
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        // 키운 만큼 바깥 여백을 2pt씩 빼서, 버튼 묶음에서는 보이는 원(40pt) 크기만 차지하게 합니다.
        .padding(-2)
    }
    
    var exploreHereControl: some View {
        Button {
            store.send(.didTapExploreHereButton)
        } label: {
            HStack(spacing: 7) {
                Image(.iconRotate)

                Text("이 지역 재탐색")
                    .nekiFont(.body14SemiBold)
                    .foregroundStyle(.gray800)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.white)
                    .nekiShadow(.button)
            )
            .overlay {
                Capsule()
                    .strokeBorder(.primary400)
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
