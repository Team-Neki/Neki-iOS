//
//  ArchiveAlbumEmptyView.swift
//  Neki-iOS
//
//  Created by OneTen on 1/21/26.
//

import SwiftUI

struct ArchiveEmptyView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Circle()
                .fill(.gray50)
                .frame(width: 104, height: 104)
            
            Text("아직 등록된 사진이 없어요\n아카이빙 페이지에서 추가해보세요!")
                .nekiFont(.body16Medium)
                .foregroundStyle(.gray300)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
