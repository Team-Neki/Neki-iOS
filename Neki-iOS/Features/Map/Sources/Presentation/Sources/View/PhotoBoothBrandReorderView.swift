//
//  PhotoBoothBrandReorderView.swift
//  Neki-iOS
//
//  Created by SwainYun on 6/4/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

public struct PhotoBoothBrandReorderView: View {
    @Bindable var store: StoreOf<PhotoBoothBrandReorderFeature>

    public init(store: StoreOf<PhotoBoothBrandReorderFeature>) {
        self.store = store
    }
    
    public var body: some View {
        List {
            Section {
                ForEach(store.brands) { brand in
                    brandCell(brand)
                }
                .onMove { source, destination in
                    store.send(.moveBrands(source, destination), animation: .easeInOut(duration: 0.2))
                }

                Color.clear
                    .frame(height: 128)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .environment(\.editMode, .constant(.active))
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.never)
        .nekiToolbar {
            NekiToolBar.back { store.send(.didTapBackButton) }
        } center: {
            NekiToolBar.textCenter("브랜드 순서 변경")
        } right: {
            NekiToolBar.textRight("완료", isEnabled: store.isDoneButtonEnabled) {
                store.send(.didTapDoneButton)
            }
        }
    }

    private func brandCell(_ brand: PhotoBoothBrand) -> some View {
        BrandReorderCell(
            brand: brand,
            brandName: brand.name
        )
        .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}


// MARK: - BrandReorderCell

private struct BrandReorderCell: View {
    let brand: PhotoBoothBrand
    let brandName: String

    var body: some View {
        content
            .padding(.vertical, 10)
            .contentShape(.rect)
    }

    private var content: some View {
        HStack(spacing: 12) {
            KFImage(brand.imageURL)
                .resizable()
                .onFailureImage(.imgDefaultBrandOriginal)
                .cancelOnDisappear(true)
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(brandName)
                    .nekiFont(.body16SemiBold)
                    .foregroundStyle(.gray900)
                    .lineLimit(1)
                    .layoutPriority(1)

                Text(brand.englishName)
                    .nekiFont(.caption12Medium)
                    .foregroundStyle(.gray500)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
    }
}
