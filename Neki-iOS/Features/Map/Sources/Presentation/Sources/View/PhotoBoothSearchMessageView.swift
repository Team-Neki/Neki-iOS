//
//  PhotoBoothSearchMessageView.swift
//  Neki-iOS
//
//  Created by J.H. Moon on 10/15/26.
//

import SwiftUI

/// 검색 안내, 결과 없음, 요청 실패를 알리는 아이콘과 문구입니다.
///
/// 검색 화면과 검색 결과 시트가 같은 모습으로 알리도록 함께 씁니다. 놓일 자리의 크기는 쓰는 쪽이 정합니다.
struct PhotoBoothSearchMessageView: View {
    let image: ImageResource
    let title: String
    var caption: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(image)

            VStack(spacing: 8) {
                Text(title)
                    .nekiFont(.body16Medium)
                    .foregroundStyle(.gray500)

                if let caption {
                    Text(caption)
                        .nekiFont(.caption11Medium)
                        .foregroundStyle(.gray300)
                }
            }
            .multilineTextAlignment(.center)
        }
    }
}


// MARK: - PhotoBoothSearchMessageView + Failure

extension PhotoBoothSearchMessageView {
    /// 검색 요청이 실패한 원인을 알립니다.
    init(failure: PhotoBoothSearchFailure) {
        switch failure {
        case .network:
            self.init(image: .iconNetworkError, title: "네트워크 연결이 불안정해요\n잠시 후 다시 시도해주세요.")
        case .unknown:
            self.init(image: .iconNetworkError, title: "일시적인 오류가 발생했어요\n잠시 후 다시 시도해주세요.")
        }
    }
}
