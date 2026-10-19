//
//  OverlappingMarkerController.swift
//  Neki-iOS
//
//  Created by Codex on 10/17/26.
//

import Foundation
import UIKit
import NMapsMap

/// 동일 좌표 POI에 사용하는 개별 지도 마커의 생명주기와 화면 좌표 투영을 관리합니다.
///
/// TCA 상태에는 지도 SDK 객체를 저장하지 않고, `NaverMapRepresentable`의 어댑터 계층 안에서만
/// 일시적인 마커 상태를 유지합니다.
@MainActor
final class OverlappingMarkerController {
    typealias BoothID = PhotoBooth.ID

    struct Configuration {
        let markerSize: CGSize
        let minimumGap: CGFloat
        let captionColorHex: UInt
        let captionTextSize: CGFloat
        let normalZIndex: Int
        let selectedZIndex: Int
    }

    private struct PositionedMarker {
        let id: BoothID
        let offset: CGPoint
    }

    var onMarkerTapped: ((BoothID) -> Void)?
    var onMarkerImageRequested: ((PhotoBooth, NMFMarker, Bool) -> Void)?
    var onMarkerImageCancellationRequested: ((BoothID) -> Void)?

    private let configuration: Configuration
    private var markersByID: [BoothID: NMFMarker] = [:]
    private var markerStateByID: [BoothID: PhotoBoothMarkerPresentationState] = [:]
    private var positionedMarkersByCoordinate: [GeographicCoordinate: [PositionedMarker]] = [:]
    private var groups: [GeographicCoordinate: [BoothID]] = [:]
    private var selectedBoothID: BoothID?
    private var isExpanded = false

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func update<Booths: Collection>(
        photoBooths: Booths,
        groups newGroups: [GeographicCoordinate: [BoothID]],
        selectedBoothID newSelectedBoothID: BoothID?,
        isExpanded newIsExpanded: Bool,
        mapView: NMFMapView
    ) where Booths.Element == PhotoBooth {
        let overlappingIDs = Set(newGroups.values.joined())
        let removedIDs = markersByID.keys.filter { overlappingIDs.contains($0) == false }
        for id in removedIDs {
            markersByID.removeValue(forKey: id)?.mapView = nil
            markerStateByID.removeValue(forKey: id)
            onMarkerImageCancellationRequested?(id)
        }

        let selectionChanged = selectedBoothID != newSelectedBoothID
        let visibilityChanged = isExpanded != newIsExpanded
        if newIsExpanded == false {
            for id in overlappingIDs where markersByID[id] != nil {
                markersByID[id]?.mapView = nil
                if visibilityChanged { onMarkerImageCancellationRequested?(id) }
            }
        }

        for booth in photoBooths where newIsExpanded && overlappingIDs.contains(booth.id) {
            let marker: NMFMarker
            let isNew: Bool
            if let existingMarker = markersByID[booth.id] {
                marker = existingMarker
                isNew = false
            } else {
                marker = makeMarker(for: booth)
                markersByID[booth.id] = marker
                isNew = true
            }

            let state = PhotoBoothMarkerPresentationState(booth: booth)
            let markerChanged = markerStateByID[booth.id] != state
            let selectionAffectsMarker = selectionChanged
                && (booth.id == newSelectedBoothID || booth.id == selectedBoothID)
            if isNew || markerChanged || selectionAffectsMarker || (visibilityChanged && newIsExpanded) {
                update(marker, for: booth, isSelected: booth.id == newSelectedBoothID)
            }
            markerStateByID[booth.id] = state
            marker.mapView = newIsExpanded ? mapView : nil
        }

        let groupCompositionChanged = groups != newGroups
        groups = newGroups
        selectedBoothID = newSelectedBoothID
        isExpanded = newIsExpanded
        if groupCompositionChanged {
            positionedMarkersByCoordinate = makePositionedMarkers(groups: newGroups)
        }
        if newIsExpanded && (groupCompositionChanged || visibilityChanged) { updatePositions(mapView: mapView) }
    }

    func updatePositions(mapView: NMFMapView) {
        for (coordinate, positionedMarkers) in positionedMarkersByCoordinate {
            let origin = NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude)
            let originPoint = mapView.projection.point(from: origin)
            guard originPoint.x.isFinite, originPoint.y.isFinite else { continue }

            for positionedMarker in positionedMarkers {
                let point = CGPoint(
                    x: originPoint.x + positionedMarker.offset.x,
                    y: originPoint.y + positionedMarker.offset.y
                )
                let position = mapView.projection.latlng(from: point)
                guard position.lat.isFinite, position.lng.isFinite, position.isWithinCoverage() else { continue }
                markersByID[positionedMarker.id]?.position = position
            }
        }
    }

    private func makePositionedMarkers(groups: [GeographicCoordinate: [BoothID]]) -> [GeographicCoordinate: [PositionedMarker]] {
        groups.mapValues { boothIDs in
            let offsets = OverlappingMarkerLayout.offsets(
                count: boothIDs.count,
                markerSize: configuration.markerSize,
                minimumGap: configuration.minimumGap
            )
            return zip(boothIDs, offsets).map { id, offset in
                PositionedMarker(id: id, offset: offset)
            }
        }
    }

    private func makeMarker(for booth: PhotoBooth) -> NMFMarker {
        let marker = NMFMarker(position: NMGLatLng(lat: booth.coordinate.latitude, lng: booth.coordinate.longitude))
        return marker
    }

    private func update(_ marker: NMFMarker, for booth: PhotoBooth, isSelected: Bool) {
        BoothMarkerConfigurator.configure(
            marker,
            for: booth,
            isSelected: isSelected,
            captionColorHex: configuration.captionColorHex,
            captionTextSize: configuration.captionTextSize,
            normalZIndex: configuration.normalZIndex,
            selectedZIndex: configuration.selectedZIndex
        )
        marker.touchHandler = { [weak self, id = booth.id] _ in
            self?.onMarkerTapped?(id)
            return true
        }
        onMarkerImageRequested?(booth, marker, isSelected)
    }
}
