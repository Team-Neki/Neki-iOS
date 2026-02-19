//
//  NearPhotoBoothListSheet.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/8/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct NearPhotoBoothListSheet: View {
    @Bindable var store: StoreOf<PhotoBoothListFeature>
    
    private let brandNameFormatter = PhotoBoothNameFormatter()
    
    init(store: StoreOf<PhotoBoothListFeature>) { self.store = store }
    
    var body: some View {
        ScrollView(.vertical) {
            photoBoothBrandFilterOptionsSection
            nearByPhotoBoothListSection
        }
    }
}


// MARK: - NearPhotoBoothListSheet + Subviews

private extension NearPhotoBoothListSheet {
    var photoBoothBrandFilterOptionsSection: some View {
        Section {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 2) {
                    ForEach(store.brands, id: \.self) { brand in
                        filterCell(brand)
                    }
                }
            }
            .scrollIndicators(.never)
            .contentMargins(.horizontal, 20, for: .scrollContent)
        } header: {
            Text("네컷 사진 브랜드")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.top, 4)
                .nekiFont(.title18Bold)
        }
    }
    
    @ViewBuilder
    func filterCell(_ brand: PhotoBoothBrand) -> some View {
        let isSelected: Bool = store.filteredBrands.contains(brand)
        
        Button {
            store.send(.selectFilterOption(brand))
        } label: {
            VStack(spacing: 8) {
                KFImage(brand.imageURL)
                    .resizable()
                    .onFailureImage(.imgDefaultBrandOriginal)
                    .frame(width: 56, height: 56)
                    .clipShape(.circle)
                    .overlay {
                        ZStack {
                            Circle()
                                .fill(isSelected ? .primary400.opacity(0.5) : .clear)
                            
                            if isSelected {
                                Image(.iconCheckmarkWhite)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                
                Text(brandNameFormatter.format(brand: brand))
                    .font(.neki(isSelected ? .body14SemiBold : .body14Medium))
                    .foregroundStyle(isSelected ? .primary400 : .gray900)
                    .lineLimit(2)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 56)
            .padding(.horizontal, 5)
            .padding(.bottom, 48)
        }
    }
    
    var nearByPhotoBoothListSection: some View {
        Section {
            if store.photoBooths.isEmpty {
                unavailableView
            } else {
                LazyVStack(alignment: .leading) {
                    ForEach(store.visibleBooths) { photoBooth in
                        nearByPhotoBoothCell(photoBooth)
                    }
                }
            }
        } header: {
            HStack {
                HStack(spacing: 2) {
                    Text("가까운").foregroundStyle(.primary400) +
                    Text(" ") +
                    Text("포토") +
                    Text(" ") +
                    Text("부스")
                    
                    Image(.iconPinClip)
                }
                
                Spacer()
                
                Image(.iconExclamationMarkGray)
                    .onTapGesture { store.send(.toggleTooltip) }
                    .nekiTooltip(isPresented: $store.isTooltipPresented, "가까운 네컷 사진 브랜드는\n1Km 기준으로 표시돼요.")
            }
            .nekiFont(.title18Bold)
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    func nearByPhotoBoothCell(_ photoBooth: PhotoBooth) -> some View {
        HStack(spacing: 16) {
            KFImage(photoBooth.brand.imageURL)
                .resizable()
                .onFailureImage(.imgDefaultBrandOriginal)
                .cancelOnDisappear(true)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(photoBooth.brand.name)
                        .nekiFont(.title18SemiBold)
                        .foregroundStyle(.gray900)
                    
                    Text(photoBooth.name)
                        .nekiFont(.caption12Medium)
                        .foregroundStyle(.gray600)
                }
                
                Text(photoBooth.nearbyDistance?.distanceString ?? "")
                    .nekiFont(.caption12Medium)
                    .foregroundStyle(.gray400)
            }
        }
        .contentShape(.rect)
        .onTapGesture { store.send(.didTapBooth(photoBooth)) }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
    
    var unavailableView: some View {
        Text("1km 이내에 가까운 네컷 사진관이 없어요!")
            .nekiFont(.body16Medium)
            .foregroundStyle(.gray500)
            .frame(height: 375)
    }
}
