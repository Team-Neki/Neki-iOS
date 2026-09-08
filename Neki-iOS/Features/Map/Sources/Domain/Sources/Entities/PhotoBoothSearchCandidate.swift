//
//  PhotoBoothSearchCandidate.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/23/26.
//

import Foundation

/// 지도 검색에서 사용자가 선택할 수 있는 검색 후보입니다.
///
/// 후보를 고른 뒤 필요한 값이 유형마다 다르므로 합 타입으로 표현합니다.
/// 지역은 법정동코드로, 지하철역은 역명과 노선명으로 부스를 조회하며,
/// 포토부스는 검색 응답에 지도에 필요한 값이 모두 들어 있어 후속 조회가 없습니다.
public enum PhotoBoothSearchCandidate: Equatable, Sendable, Identifiable {
    case region(PhotoBoothSearchRegion)
    case subwayStation(PhotoBoothSearchStation)
    case photoBooth(PhotoBooth)

    /// 목록에서 후보를 구분하는 식별자입니다.
    ///
    /// 지하철역은 한 역이 노선 수만큼 내려오므로 역명만으로는 구분되지 않아 노선명까지 포함합니다.
    public var id: String {
        switch self {
        case let .region(region): "region:\(region.code)"
        case let .subwayStation(station): "station:\(station.name):\(station.lineName)"
        case let .photoBooth(photoBooth): "photoBooth:\(photoBooth.id)"
        }
    }

    public var type: PhotoBoothSearchCandidateType {
        switch self {
        case .region: .region
        case .subwayStation: .subwayStation
        case .photoBooth: .photoBooth
        }
    }

    /// 목록에 표시할 이름입니다.
    ///
    /// 서버는 화면에 보일 문자열을 조합하지 않으므로 원본 필드를 클라이언트에서 이어붙입니다.
    public var displayName: String {
        switch self {
        case let .region(region): region.fullName
        case let .subwayStation(station): "\(station.name)역 \(station.lineName)"
        case let .photoBooth(photoBooth): "\(photoBooth.brand.name) \(photoBooth.name)"
        }
    }

    /// 서버가 검색어와 대조한 이름입니다.
    ///
    /// 검색은 이 값에 대한 접두 일치이므로, 표시 이름에서 강조할 구간을 찾는 기준이 됩니다.
    public var matchedName: String {
        switch self {
        case let .region(region): region.name
        case let .subwayStation(station): station.name
        case let .photoBooth(photoBooth): photoBooth.name
        }
    }

    /// 사용자 현재 위치로부터의 거리를 계산할 좌표입니다.
    ///
    /// 지역은 기준이 될 좌표가 없고, 지하철역은 검색 응답에 좌표가 내려오지 않아 현재는 `nil`입니다.
    /// 역 좌표가 응답에 추가되면 ``PhotoBoothSearchStation``에 좌표를 더해 여기서 반환하면 됩니다.
    public var coordinate: GeographicCoordinate? {
        switch self {
        case .region, .subwayStation: nil
        case let .photoBooth(photoBooth): photoBooth.coordinate
        }
    }
}

/// 고른 뒤 부스 목록을 요청할 대상입니다.
///
/// 서버가 지역과 지하철역 중 정확히 하나만 받으므로(둘 다 없거나 둘 다 있으면 거절합니다)
/// 합 타입으로 표현해 요청 단계에서 하나만 담기도록 합니다.
public enum PhotoBoothSearchTarget: Equatable, Sendable {
    case region(code: String)
    case subwayStation(name: String, lineName: String)
}

/// 지역 검색 결과 한 건입니다.
///
/// 검색어와 직접 매칭되는 구역만 내려오며, 시도(`SIDO`)는 검색 대상이 아닙니다.
public struct PhotoBoothSearchRegion: Equatable, Sendable {
    /// 법정동코드 10자리. 지역에 속한 부스를 조회할 때 그대로 넘깁니다.
    public let code: String
    /// 가장 아래 계층의 이름. 서버가 검색어와 대조하는 값입니다.
    public let name: String
    /// 전체 경로. 같은 이름을 가진 지역을 구분하는 용도입니다.
    public let fullName: String

    /// 지역 검색 결과를 생성합니다.
    ///
    /// - Parameters:
    ///   - code: 법정동코드 10자리
    ///   - name: 가장 아래 계층의 이름
    ///   - fullName: 시도부터 이어지는 전체 경로
    public init(code: String, name: String, fullName: String) {
        self.code = code
        self.name = name
        self.fullName = fullName
    }
}

/// 지하철역 검색 결과 한 건입니다.
///
/// 노선마다 승강장 위치가 달라 주변 부스 결과도 달라지므로 한 역이 노선 수만큼 내려옵니다.
/// 역명과 노선명이 함께 역을 식별하며, 부스 조회에 그대로 넘깁니다.
public struct PhotoBoothSearchStation: Equatable, Sendable {
    /// 역명. `역` 접미사가 없으므로 화면에 붙일 때 클라이언트가 추가합니다.
    public let name: String
    public let lineName: String

    /// 지하철역 검색 결과를 생성합니다.
    ///
    /// - Parameters:
    ///   - name: `역` 접미사가 없는 역명
    ///   - lineName: 노선명
    public init(name: String, lineName: String) {
        self.name = name
        self.lineName = lineName
    }
}

/// 검색어 기반 검색 후보 종류입니다.
public enum PhotoBoothSearchCandidateType: Equatable, Sendable, CaseIterable {
    case region         // 지역구
    case subwayStation  // 지하철역
    case photoBooth     // 포토부스

    /// 검색 결과 목록에서의 노출 순서입니다. 값이 작을수록 앞에 노출합니다.
    ///
    /// 지역 → 지하철역 → 포토부스 순서로 노출하는 검색 정책을 표현합니다.
    public var displayOrder: Int {
        switch self {
        case .region: 0
        case .subwayStation: 1
        case .photoBooth: 2
        }
    }

    /// 현재 위치 기준 거리 정보를 함께 노출하는 종류인지 여부입니다.
    ///
    /// 지역은 거리 정보를 노출하지 않습니다.
    public var providesDistance: Bool {
        switch self {
        case .region: false
        case .subwayStation, .photoBooth: true
        }
    }

    /// 정책 순서로 정렬한 전체 종류입니다.
    public static var displayOrdered: [Self] {
        allCases.sorted { $0.displayOrder < $1.displayOrder }
    }
}
