//
//  MyPageView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/19/26.
//

import SwiftUI
import ComposableArchitecture

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
            .padding(isLarge ? .zero : 20)
    }
    
    var profileArea: some View {
        // TODO: 사용자 프로필 연결 필요 (Auth Feature 작업 이후 변경 예정)
        HStack(spacing: 16) {
            Circle()
                .frame(width: 78, height: 78)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.user.nickname)
                        .nekiFont(.title18SemiBold)
                        .foregroundStyle(.gray900)
                    
                    Text(store.user.providerType.name)
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
        Section {
            VStack(spacing: 24) {
                ForEach(item.includedItems) { cellItem in
                    sectionCell(cellItem)
                }
            }
        } header: {
            Text(item.title)
                .nekiFont(.caption12Medium)
                .foregroundStyle(.gray400)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
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
        .contentShape(.rect)
        .onTapGesture { store.send(.cellTapped(item)) }
    }
}
