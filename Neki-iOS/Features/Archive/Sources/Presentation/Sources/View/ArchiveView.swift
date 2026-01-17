//
//  ArchiveView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/7/26.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct ArchiveView: View {
    
    let store: StoreOf<ArchiveFeature>
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                albumSection
                    .padding(.bottom, 28)
                
                recentPhotoSection
            }
        }
        .scrollIndicators(.never)
        .nekiToolbar(
            left: .icon(.iconLogo, action: nil),
            // TODO: - 이미지 추가 액션과 알림 확인 액션 추가
            right: .both([.icon(.iconPlusRed, action: {}), .icon(.iconBellFill, action: {})])
        )
        .task {
            await store.send(.onAppear).finish()
        }
    }
}


// MARK: - Subviews

private extension ArchiveView {
    
    // 앨범 섹션
    var albumSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Text("앨범")
                    .nekiFont(.title20Bold)
                    .foregroundStyle(.gray900)
                
                Spacer()
                
                Button {
                    // TODO: - 전체 앨범 이동
                    print("전체 앨범 이동 클릭")
                } label: {
                    HStack(alignment: .center, spacing: 0) {
                        Text("전체 앨범")
                            .nekiFont(.body14Regular)
                            .foregroundStyle(.gray500)
                        
                        Image(.iconChevronRight)
                    }
                }
            }
            .padding(.bottom, 12)
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.albums) { album in
                        AlbumCardView(album: album)
                            .onTapGesture {
                                store.send(.albumTapped(album))
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // 최근 사진 섹션
    var recentPhotoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("최근 사진")
                    .nekiFont(.title20Bold)
                    .foregroundStyle(.gray900)
                
                Spacer()
                
                Button {
                    store.send(.tapAllPhotos)
                } label: {
                    HStack(alignment: .center, spacing: 0) {
                        Text("모든 사진")
                            .nekiFont(.body14Regular)
                            .foregroundStyle(.gray500)
                        
                        Image(.iconChevronRight)
                    }
                }
            }
            .padding(.bottom, 12)
            
            MasonryGridView(
                items: Array(store.photos),
                columns: 2
            ) { item in
                ArchiveImageView(item: item)
                    .onTapGesture {
                        store.send(.imageTapped(item))
                    }
            }
            .padding(.bottom, 76)
        }
        .padding(.horizontal, 20)
    }
}
