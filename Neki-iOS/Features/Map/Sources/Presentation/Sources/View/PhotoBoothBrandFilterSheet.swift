//
//  PhotoBoothBrandFilterSheet.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 9/8/26.
//

import SwiftUI
import ComposableArchitecture

/// 검색 결과 목록에서 브랜드를 골라 거르는 바텀시트입니다.
///
/// 칩은 `이 지역 포토부스` 목록의 브랜드 필터와 같은 방식으로 누르는 즉시 토글되어 목록에 반영됩니다.
/// 노출하는 브랜드는 검색 결과에 실제로 있는 브랜드(``PhotoBoothListFeature/State/selectableBrands``)뿐입니다.
struct PhotoBoothBrandFilterSheet: View {
    let store: StoreOf<PhotoBoothListFeature>
    /// 시트 높이는 내용에 맞춰 재고, 0pt 디텐트를 피하려 1로 시작합니다.
    @State private var contentHeight: CGFloat = 1

    private enum Constants {
        static let dragHandleSize = CGSize(width: 45, height: 4)
        static let chipHorizontalSpacing: CGFloat = 6
        static let chipVerticalSpacing: CGFloat = 10
    }

    var body: some View {
        VStack(spacing: 4) {
            dragHandle

            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    Text("브랜드 필터")
                        .nekiFont(.title20SemiBold)
                        .foregroundStyle(.gray900)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    brandChips
                        .padding(.top, 12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                Button {
                    store.send(.dismissSearchResultBrandFilterSheet)
                } label: {
                    Text("확인")
                }
                .buttonStyle(.nekiCTA(.primary))
                .padding(.horizontal, 20)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .safeAreaPadding(.bottom)
        .presentationBackground(.white)
        // 하단 Safe Area 여백까지 포함해 잰 높이로 디텐트를 정합니다. (`PoseView`의 필터 시트와 같은 순서)
        .autoSizingDetent($contentHeight)
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
    }
}


// MARK: - PhotoBoothBrandFilterSheet + Subviews

private extension PhotoBoothBrandFilterSheet {
    var dragHandle: some View {
        Capsule()
            .fill(.gray100)
            .frame(width: Constants.dragHandleSize.width, height: Constants.dragHandleSize.height)
            .padding(.vertical, 10)
    }

    var brandChips: some View {
        NekiFlowLayout(
            horizontalSpacing: Constants.chipHorizontalSpacing,
            verticalSpacing: Constants.chipVerticalSpacing
        ) {
            ForEach(store.selectableBrands) { brand in
                BrandFilterRoundRectChip(brand: brand, isSelected: store.filteredBrands.contains(brand)) {
                    store.send(.selectFilterOption(brand))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - Preview

#Preview("내용") {
    PhotoBoothBrandFilterSheet(
        store: PhotoBoothListPreviewData.store(
            PhotoBoothListPreviewData.searchResultState(
                selecting: [PhotoBoothListPreviewData.brands[1], PhotoBoothListPreviewData.brands[4]]
            )
        )
    )
}

#Preview("바텀시트로 띄운 모습") {
    Color.gray50
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PhotoBoothBrandFilterSheet(
                store: PhotoBoothListPreviewData.store(PhotoBoothListPreviewData.searchResultState())
            )
        }
}
