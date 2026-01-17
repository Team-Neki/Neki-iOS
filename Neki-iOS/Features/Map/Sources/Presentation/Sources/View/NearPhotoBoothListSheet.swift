//
//  NearPhotoBoothListSheet.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/8/26.
//

import SwiftUI
import ComposableArchitecture

struct NearPhotoBoothListSheet: View {
    @Bindable var store: StoreOf<PhotoBoothListFeature>
    
    init(store: StoreOf<PhotoBoothListFeature>) { self.store = store }
    
    var body: some View {
        ScrollView(.vertical) {
            photoBoothBrandFilterOptionsSection
            nearByPhotoBoothListSection
        }
        .nekiWarningAlert(isPresented: $store.isWarningAlertPresented, titleMessage: "가까운 네컷 사진 브랜드는 1km 기준으로 표시돼요.") { // TODO: 얼럿 등장 위치 상위 화면으로 옮겨야 할 수도 있음
            store.send(.dismissWarningAlert)
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
                Image(brand.logoImageResource)
                    .resizable()
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
                
                Text(brand.displayName)
                    .nekiFont(isSelected ? .body14SemiBold : .body14Medium)
                    .foregroundStyle(isSelected ? .primary400 : .gray900)
                    .lineLimit(2)
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
                    ForEach(store.photoBooths) { photoBooth in
                        nearByPhotoBoothCell(photoBooth)
                    }
                }
            }
        } header: {
            HStack {
                Text("가까운")
                    .foregroundStyle(.primary400)
                
                Text("네컷 사진 브랜드")
                
                Spacer()
                
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.gray400)
                    .onTapGesture { store.send(.showWarningAlert) }
            }
            .nekiFont(.title18Bold)
            .padding(.horizontal, 20)
        }
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    func nearByPhotoBoothCell(_ photoBooth: PhotoBooth) -> some View {
        HStack(spacing: 16) {
            Image(photoBooth.brand.logoImageResource)
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(photoBooth.name)
                        .nekiFont(.title18SemiBold)
                        .foregroundStyle(.gray900)
                    
                    Text("사당역점") // TODO: 실제 지점 정보를 표시해야 합니다.
                        .nekiFont(.caption12Medium)
                        .foregroundStyle(.gray600)
                }
                
                Text("300m") // TODO: 실제 거리 값을 표시해야 합니다
                    .nekiFont(.caption12Medium)
                    .foregroundStyle(.gray400)
            }
        }
        .contentShape(.rect)
        .onTapGesture { store.send(.didTapBooth(photoBooth)) }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
    
    var unavailableView: some View { // TODO: 디자인 수정될 여지 있습니다.
        Text("1km 이내에 가까운 네컷 사진관이 없어요!")
            .nekiFont(.body16Medium)
            .foregroundStyle(.gray500)
            .frame(height: 375) // TODO: 스크롤뷰 내부 요소는 상단 정렬이라, 여기서 고정 높이를 줘서 디자인 시안과 맞췄습니다.
    }
}

#Preview {
    TabView {
        NaverMapView(store: Store(initialState: MapFeature.State(), reducer: { MapFeature() }))
    }
}
