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
    @Namespace private var tabNamespace

    private let brandNameFormatter = PhotoBoothNameFormatter()
    
    init(store: StoreOf<PhotoBoothListFeature>) { self.store = store }
    
    var body: some View {
        ScrollView(.vertical) {
            photoBoothBrandFilterOptionsSection
            listTabBar

            Group {
                switch store.selectedTab {
                case .nearby:
                    nearByPhotoBoothListSection
                case .favorite:
                    favoritePhotoBoothListSection
                }
            }
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
            .scrollDisabled(false)
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
    
    var listTabBar: some View {
        HStack(spacing: 0) {
            ForEach(PhotoBoothListFeature.ListTab.allCases) { tab in
                let isSelected = store.selectedTab == tab
                
                Button {
                    store.send(.selectTab(tab), animation: .easeInOut(duration: 0.2))
                } label: {
                    HStack(spacing: 2) {
                        Image(tab == .nearby ? .iconPinClip : .iconDoubleHeart)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .saturation(isSelected ? 1 : 0)
                        
                        Text(tab.title)
                            .nekiFont(.body14SemiBold)
                            .foregroundStyle(isSelected ? .gray800 : .gray500)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white)
                                .matchedGeometryEffect(id: "selectedPhotoBoothListTab", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(4)
        .background(.gray50)
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    var nearByPhotoBoothListSection: some View {
        Section {
            if store.visibleBooths.isEmpty {
                unavailableView("1km 이내에 가까운 네컷 사진관이 없어요!")
            } else {
                LazyVStack(alignment: .leading, spacing: .zero) {
                    ForEach(store.visibleBooths) { photoBooth in
                        photoBoothCell(photoBooth)
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
    
    var favoritePhotoBoothListSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("저장한 포토부스 총 \(store.favoriteBoothCount)곳")
                    .foregroundStyle(.gray300)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                if store.visibleFavoriteBooths.isEmpty {
                    unavailableView("저장한 포토부스가 없어요.")
                } else {
                    LazyVStack(alignment: .leading, spacing: .zero) {
                        ForEach(store.visibleFavoriteBooths) { photoBooth in
                            photoBoothCell(photoBooth)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    func photoBoothCell(_ photoBooth: PhotoBooth) -> some View {
        HStack(spacing: 16) {
            KFImage(photoBooth.brand.imageURL)
                .resizable()
                .onFailureImage(.imgDefaultBrandOriginal)
                .cancelOnDisappear(true)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(photoBooth.brand.name)
                    .nekiFont(.title18SemiBold)
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
                store.send(.didTapFavorite(photoBooth))
            } label: {
                Image(photoBooth.isFavorite ? .iconHeart28Fill : .iconHeart28Gray)
            }
            .buttonStyle(.plain)
        }
        .contentShape(.rect)
        .onTapGesture { store.send(.didTapBooth(photoBooth)) }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    func unavailableView(_ message: String) -> some View {
        VStack(alignment: .center) {
            Image(.iconPlace)
            
            Text(message)
                .nekiFont(.body16Medium)
                .foregroundStyle(.gray500)
                .frame(maxWidth: .infinity, minHeight: 375, alignment: .center)
        }
    }
}
