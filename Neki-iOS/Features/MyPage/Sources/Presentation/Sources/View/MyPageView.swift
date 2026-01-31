//
//  MyPageView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/19/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct MyPageView: View {
    typealias SectionItem = MyPageFeature.SectionItem
    typealias SectionCellItem = MyPageFeature.SectionCellItem
    
    @Bindable var store: StoreOf<MyPageFeature>
    
    var body: some View {
        VStack(spacing: .zero) {
            profileArea
            
            divider(isLarge: true)
            
            section(.authorizationSettings)
            
            divider(isLarge: false)
            
            section(.support)
            
            Spacer()
        }
        .nekiToolbar(
            left: .text("마이페이지", action: nil),
            right: .icon(.iconBellFill, action: {}) // TODO: 알림기능 연결 필요
        )
    }
}


// MARK: - MyPageView + Subviews

private extension MyPageView {
    func divider(isLarge: Bool) -> some View {
        Rectangle()
            .frame(height: isLarge ? 11 : 1)
            .foregroundStyle(isLarge ? .gray25 : .gray50)
            .padding(.horizontal, isLarge ? .zero : 20)
    }
    
    var profileArea: some View {
        HStack(spacing: 16) {
            KFImage(store.user.profileImageURL)
                .resizable()
                .onFailureImage(.iconDefaultProfile)
                .aspectRatio(contentMode: .fill)
                .frame(width: 78, height: 78)
                .clipShape(.circle)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.user.nickname)
                        .nekiFont(.title18SemiBold)
                        .foregroundStyle(.gray900)
                    
                    Text("\(store.user.providerType.name.uppercased()) 로그인")
                        .nekiFont(.caption12Regular)
                        .foregroundStyle(.gray600)
                }
                
                Spacer()
                
                Image(.iconChevronRight)
            }
        }
        .contentShape(.rect)
        .onTapGesture { store.send(.profileTapped) }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    func section(_ item: SectionItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            Text(item.title)
                .nekiFont(.caption12Medium)
                .foregroundStyle(.gray400)
                .padding(.top, 12)
            
            // Content
            VStack(spacing: 12) {
                ForEach(item.includedItems) { cellItem in
                    sectionCell(cellItem)
                }
            }
        }
        .padding(.horizontal)
    }
    
    func sectionCell(_ item: SectionCellItem) -> some View {
        HStack {
            Text(item.title)
                .nekiFont(.body16Medium)
                .foregroundStyle(.gray900)
            
            Spacer()
            
            if item.hasLink {
                Image(.iconChevronRight)
            } else {
                Text("v.1.3.1") // TODO: 실제 버전정보 표시하도록 해야함
                    .nekiFont(.body14Medium)
                    .foregroundStyle(.gray500)
            }
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
        .onTapGesture { store.send(.cellTapped(item)) }
    }
}

#Preview {
    MyPageView(store: .init(initialState: MyPageFeature.State(user: .init(id: 1, nickname: "Swain", email: "dsad", profileImageURL: nil, providerType: .apple)), reducer: { MyPageFeature() }))
}
