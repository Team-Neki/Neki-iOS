//
//  AlbumCard.swift
//  Neki-iOS
//
//  Created by OneTen on 1/17/26.
//

import SwiftUI
import Kingfisher
import os

struct AlbumCard: View {
    let album: AlbumItem
    
    private let cardWidth: CGFloat = 124
    private let cardHeight: CGFloat = 166
    
    var body: some View {
        ZStack(alignment: .bottom) {
            KFImage(album.coverImageURL)
                .placeholder({
                    Image(.temporaryBranding)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                })
                .onFailureImage(.temporaryBranding)
                .resizable()
                .retry(maxCount: 3, interval: .seconds(5))
                .onFailure { error in
                    Logger.presentation.error("앨범이미지 로드 실패: \(error)")
                    Logger.presentation.error("실패한 앨범이미지 id: \(album.id)")
                }
                .cancelOnDisappear(true)
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
            
            UnionShape()
                .fill(album.isFavorite ? .primary400.opacity(0.9) : .gray900.opacity(0.9))
            
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(album.count)장")
                        .nekiFont(.body14Medium)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text(album.title)
                        .nekiFont(.body16SemiBold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.leading, 10)
                
                Spacer()
                
                if album.isFavorite {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 9.75, height: 9.25)
                        .padding(.vertical, 5.38)
                        .padding(.horizontal, 5.12)
                        .background(.gray25.opacity(0.3))
                        .clipShape(Circle())
                        .foregroundStyle(.white)
                        .padding(.trailing, 8)
                        .padding(.bottom, 2)
                } else {
                    Color.clear
                        .frame(width: 20, height: 20)
                        .padding(.trailing, 8)
                }
            }
            .padding(.bottom, 8)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


// MARK: - 익성님이 공유해준 앨범 커버 만드는 로직

private extension AlbumCard {
    struct UnionShape: Shape {
        func path(in rect: CGRect) -> Path {
            let vw: CGFloat = 124
            let vh: CGFloat = 65
            
            let s = min(rect.width / vw, rect.height / vh)
            let drawnW = vw * s
            let dx = (rect.width - drawnW) / 2
            let dy = rect.height - (vh * s)
            
            var p = Path()
            
            p.move(to: CGPoint(x: 124, y: 65))
            p.addLine(to: CGPoint(x: 0, y: 65))
            p.addLine(to: CGPoint(x: 0, y: 8))
            p.addCurve(
                to: CGPoint(x: 8, y: 0),
                control1: CGPoint(x: 0, y: 3.58),
                control2: CGPoint(x: 3.58, y: 0)
            )
            p.addLine(to: CGPoint(x: 58.54, y: 0))
            p.addCurve(
                to: CGPoint(x: 64.96, y: 3.23),
                control1: CGPoint(x: 61.07, y: 0),
                control2: CGPoint(x: 63.45, y: 1.2)
            )
            p.addLine(to: CGPoint(x: 69.2, y: 8.93))
            p.addCurve(
                to: CGPoint(x: 75.58, y: 12.16),
                control1: CGPoint(x: 70.7, y: 10.95),
                control2: CGPoint(x: 73.06, y: 12.15)
            )
            p.addLine(to: CGPoint(x: 116.04, y: 12.35))
            p.addCurve(
                to: CGPoint(x: 124, y: 20.34),
                control1: CGPoint(x: 120.44, y: 12.36),
                control2: CGPoint(x: 124, y: 15.94)
            )
            p.addLine(to: CGPoint(x: 124, y: 65))
            p.closeSubpath()
            
            var t = CGAffineTransform(translationX: dx, y: dy)
            t = t.scaledBy(x: s, y: s)
            return p.applying(t)
        }
    }
}

