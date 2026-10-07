//
//  PhotoBoothSearchCandidateCell.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 8/27/26.
//

import SwiftUI
import Dependencies

/// 검색 후보 목록에서 후보 한 건을 표시하는 셀입니다.
///
/// 후보 종류에 따라 아이콘과 아이콘 배경색이 결정되며, 이름에서 검색어와 일치하는 구간은 굵게 강조됩니다.
struct PhotoBoothSearchCandidateCell: View {
    private let candidate: PhotoBoothSearchCandidate
    private let keyword: String
    private let showsDivider: Bool
    private let action: () -> Void
    
    @Dependency(\.distanceFormatterClient) var distanceFormattingClient

    private enum Metrics {
        static let horizontalPadding: CGFloat = 20
        static let iconContainerSize: CGFloat = 32
        static let iconSize: CGFloat = 20
        static let iconSpacing: CGFloat = 16
        static let distanceSpacing: CGFloat = 17
        static let dividerSpacing: CGFloat = 12
        static let dividerHeight: CGFloat = 1

        /// 구분선은 아이콘을 지나 이름 텍스트 시작점에 맞춰 시작합니다.
        static var dividerLeadingInset: CGFloat { horizontalPadding + iconContainerSize + iconSpacing }
    }

    /// 검색 후보 셀을 생성합니다.
    ///
    /// - Parameters:
    ///   - candidate: 표시할 검색 후보. 거리가 있으면 이름 옆에 함께 표시합니다.
    ///   - keyword: 이름에서 강조할 검색어. 비어 있으면 강조하지 않습니다.
    ///   - showsDivider: 셀 하단에 구분선을 표시할지 여부. 목록의 마지막 셀에서는 `false`를 전달합니다.
    ///   - action: 셀을 선택했을 때 실행할 동작
    init(
        candidate: PhotoBoothSearchCandidate,
        keyword: String,
        showsDivider: Bool = true,
        action: @escaping () -> Void
    ) {
        self.candidate = candidate
        self.keyword = keyword
        self.showsDivider = showsDivider
        self.action = action
    }

    var body: some View {
        VStack(spacing: Metrics.dividerSpacing) {
            Button(action: action) { content }
                .buttonStyle(.plain)

            if showsDivider { divider }
        }
    }
}


// MARK: - PhotoBoothSearchCandidateCell + Subviews

private extension PhotoBoothSearchCandidateCell {
    var content: some View {
        HStack(spacing: Metrics.distanceSpacing) {
            HStack(spacing: Metrics.iconSpacing) {
                icon

                Text(highlightedName)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray900)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let distance = candidate.distance {
                Text(distanceFormattingClient.string(distance: distance))
                    .nekiFont(.body14Regular)
                    .foregroundStyle(.gray500)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .contentShape(.rect)
    }

    var icon: some View {
        Image(candidate.type.icon)
            .resizable()
            .frame(width: Metrics.iconSize, height: Metrics.iconSize)
            .frame(width: Metrics.iconContainerSize, height: Metrics.iconContainerSize)
            .background(candidate.type.iconBackgroundColor)
            .clipShape(.circle)
    }

    var divider: some View {
        Rectangle()
            .fill(.gray50)
            .frame(height: Metrics.dividerHeight)
            .padding(.leading, Metrics.dividerLeadingInset)
            .padding(.trailing, Metrics.horizontalPadding)
    }

    /// 검색어와 일치하는 구간을 굵은 서체로 강조한 후보 이름입니다.
    var highlightedName: AttributedString {
        let displayName = candidate.keyword
        var name = AttributedString(displayName)

        guard let highlightRange = highlightRange(in: displayName),
              let lowerBound = AttributedString.Index(highlightRange.lowerBound, within: name),
              let upperBound = AttributedString.Index(highlightRange.upperBound, within: name)
        else { return name }

        name[lowerBound..<upperBound].font = .neki(.body16SemiBold)
        return name
    }

    /// 표시 이름에서 강조할 구간입니다.
    ///
    /// 서버는 지역명·역명뿐 아니라 브랜드명·지점명·주소로도 후보를 찾으므로, 어느 부분이
    /// 맞았는지는 응답만 봐서는 알 수 없습니다. 표시 이름 안에서 검색어를 그대로 찾으면 어느 부분이
    /// 맞았든 그 자리를 짚을 수 있어 이 구간만 강조합니다.
    ///
    /// 서버가 검색어를 다듬거나 낱말 순서와 상관없이 찾은 후보(`서울 강남` → `서울특별시 강남구`)는
    /// 표시 이름에 검색어가 그대로 없으므로 강조하지 않습니다.
    func highlightRange(in displayName: String) -> Range<String.Index>? {
        guard keyword.isEmpty == false else { return nil }
        return displayName.range(of: keyword, options: .caseInsensitive)
    }
}


// MARK: - PhotoBoothSearchCandidateType + Appearance

private extension PhotoBoothSearchCandidateType {
    var icon: ImageResource {
        switch self {
        case .region: .iconSearchRegion
        case .subwayStation: .iconSearchSubway
        case .photoBooth: .iconSearchPhotoBooth
        }
    }

    var iconBackgroundColor: Color {
        switch self {
        case .region, .subwayStation: .gray50
        case .photoBooth: .primary50
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PhotoBoothSearchCandidateCell(
            candidate: .init(type: .region, keyword: "서울특별시 강남구", filterGroup: .init()),
            keyword: ""
        ) {}

        PhotoBoothSearchCandidateCell(
            candidate: .init(type: .region, keyword: "경상남도 진주시 강남동", filterGroup: .init()),
            keyword: "강남"
        ) {}

        PhotoBoothSearchCandidateCell(
            candidate: .init(
                type: .subwayStation,
                keyword: "강남역 2호선",
                filterGroup: .init(),
                distance: .init(meters: 16_000)
            ),
            keyword: "강남"
        ) {}

        PhotoBoothSearchCandidateCell(
            candidate: .init(
                type: .photoBooth,
                keyword: "포토이즘 강남1호점",
                filterGroup: .init(),
                distance: .init(meters: 32_400)
            ),
            keyword: "강남",
            showsDivider: false
        ) {}
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.white)
}
