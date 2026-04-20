//
//  ZoomableImageView.swift
//  Neki-iOS
//
//  Created by OneTen on 3/28/26.
//

import SwiftUI
import Kingfisher

struct ZoomableImageView: View {
    let imageURL: URL?
    let isCurrent: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
            KFImage(imageURL)
                .resizable()
                .placeholder {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .retry(maxCount: 3, interval: .seconds(5))
                .cancelOnDisappear(true)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let delta = value.magnification / lastScale
                            lastScale = value.magnification
                            scale = min(max(scale * delta, 0.8), 5.0) // 0.8 ~ 5배까지
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale <= 1.0 {
                                clampOffset(geo: geo)
                            }
                        }
                )
            
            // 확대된 상태에서 이미지 이동
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { value in
                            // 드래그 가능한 최대 범위 계산
                            let maxX = max(0, (geo.size.width * (scale - 1)) / 2)
                            let maxY = max(0, (geo.size.height * (scale - 1)) / 2)
                            
                            let proposedWidth = lastOffset.width + value.translation.width
                            let proposedHeight = lastOffset.height + value.translation.height
                            
                            // 계산된 범위 내에서만 offset 적용
                            offset = CGSize(
                                width: min(max(proposedWidth, -maxX), maxX),
                                height: min(max(proposedHeight, -maxY), maxY)
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        },
                    including: scale > 1.0 ? .gesture : .subviews
                )
            
            // 더블 탭 줌
                .onTapGesture(count: 2) {
                    if scale > 1.0 {
                        resetZoom()
                    } else {
                        withAnimation(.spring()) {
                            scale = 2.5
                        }
                    }
                }
            
            // 스와이프로 다음 사진으로 넘어갔을 때 이전 사진 줌 초기화
                .onChange(of: isCurrent) { _, newValue in
                    if !newValue {
                        resetZoom(animated: false)
                    }
                }
        }
    }
    
    private func resetZoom(animated: Bool = true) {
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = 1.0
                offset = .zero
            }
        } else {
            scale = 1.0
            offset = .zero
        }
        lastScale = 1.0
        lastOffset = .zero
    }
    
    private func clampOffset(geo: GeometryProxy) {
        let maxX = max(0, (geo.size.width * (scale - 1)) / 2)
        let maxY = max(0, (geo.size.height * (scale - 1)) / 2)
        
        let newX = min(max(offset.width, -maxX), maxX)
        let newY = min(max(offset.height, -maxY), maxY)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = CGSize(width: newX, height: newY)
            lastOffset = offset
        }
    }
}
