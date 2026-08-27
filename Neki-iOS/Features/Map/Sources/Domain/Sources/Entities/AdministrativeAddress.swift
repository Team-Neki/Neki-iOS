//
//  AdministrativeAddress.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/27/26.
//

import Foundation

/// 국가별 명칭과 무관하게 행정구역의 상대적인 계층을 표현합니다.
///
/// 대한민국 주소에서는 일반적으로 `primary`가 시·도, `secondary`가 시·군·구,
/// `tertiary`가 읍·면·동에 대응합니다. 정해진 단계보다 더 세분화된 주소 체계도
/// 양의 정수인 `depth`로 표현할 수 있습니다.
public struct AdministrativeAreaLevel: Equatable, Hashable, Comparable, Sendable {
    public static let primary = Self(validatedDepth: 1)
    public static let secondary = Self(validatedDepth: 2)
    public static let tertiary = Self(validatedDepth: 3)

    public let depth: Int

    public init?(depth: Int) {
        guard depth > .zero else { return nil }
        self.depth = depth
    }

    private init(validatedDepth: Int) { self.depth = validatedDepth }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.depth < rhs.depth }
}

/// 주소를 구성하는 하나의 행정구역입니다.
public struct AdministrativeArea: Equatable, Hashable, Sendable {
    public let name: String
    public let level: AdministrativeAreaLevel

    public init?(name: String, level: AdministrativeAreaLevel) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else { return nil }
        self.name = normalizedName
        self.level = level
    }
}

/// 주소에서 지역명을 선택하는 국가 또는 지역별 표시체계입니다.
public enum AdministrativeAddressSystem: Equatable, Sendable {
    /// 대한민국 행정구역에서 실제 존재하는 상위 지역 두 개를 노출합니다.
    case southKorea
    /// 추가 국가나 지역에서 사용하는 계층 우선순위와 최대 노출 개수입니다.
    case custom(preferredLevels: [AdministrativeAreaLevel], maximumAreaCount: Int)

    fileprivate var preferredLevels: [AdministrativeAreaLevel] {
        switch self {
        case .southKorea: return [.primary, .secondary, .tertiary]
        case let .custom(preferredLevels, _): return preferredLevels
        }
    }

    fileprivate var maximumAreaCount: Int {
        switch self {
        case .southKorea: return 2
        case let .custom(_, maximumAreaCount): return max(.zero, maximumAreaCount)
        }
    }
}

/// 국가와 행정구역 계층으로 구성된 주소입니다.
public struct AdministrativeAddress: Equatable, Sendable {
    /// 주소 제공자가 국가를 식별할 수 있을 때 사용하는 ISO 3166-1 alpha-2 국가 코드입니다.
    public let countryCode: String?
    public let areas: [AdministrativeArea]

    public init?(countryCode: String? = nil, areas: [AdministrativeArea]) {
        guard areas.isEmpty == false else { return nil }
        guard Set(areas.map(\.level)).count == areas.count else { return nil }
        self.countryCode = countryCode
        self.areas = areas.sorted { $0.level < $1.level }
    }

    /// 지역별 표시 정책에 따라 실제 존재하는 행정구역을 선택합니다.
    ///
    /// 정책이 선호하는 계층이 주소에 없다면 건너뛰므로 2단계가 생략된 지역은
    /// 1·3단계를, 1단계가 생략된 주소는 2·3단계를 조합할 수 있습니다.
    public func displayAreas(using system: AdministrativeAddressSystem) -> [AdministrativeArea] {
        guard system.maximumAreaCount > .zero else { return [] }
        var includedLevels: Set<AdministrativeAreaLevel> = []
        let preferredLevels = system.preferredLevels.filter { includedLevels.insert($0).inserted }
        let preferredLevelOrder = Dictionary(uniqueKeysWithValues: preferredLevels.enumerated().map { ($1, $0) })
        let prioritizedAreas = areas.sorted {
            let lhsOrder = preferredLevelOrder[$0.level] ?? .max
            let rhsOrder = preferredLevelOrder[$1.level] ?? .max
            guard lhsOrder == rhsOrder else { return lhsOrder < rhsOrder }
            guard $0.level == $1.level else { return $0.level < $1.level }
            return $0.name < $1.name
        }
        return Array(prioritizedAreas.prefix(system.maximumAreaCount))
    }
}
