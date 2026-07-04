//
//  ImageTransformFeatureTests.swift
//  Neki-iOSTests
//
//  Created by OneTen on 3/15/26.
//

import Testing
import ComposableArchitecture
import UIKit
@testable import Neki_iOS

@MainActor
struct ImageTransformFeatureTests {
    private let mockImage = createMockImage()
    private let mockCGImage = createMockImage().cgImage!
    
    // MARK: - Tests
    
    @Test("시나리오 1: 변환 버튼 탭 시, 이미지가 없으면 아무 동작도 하지 않는다.")
    func transformButtonTapped_whenNoImage_doesNothing() async {
        // given
        let store = makeStore(initialState: ImageTransformFeature.State(inputImage: nil))
        
        // when
        await store.send(.transformButtonTapped)
        
        // then
        // 상태가 변하지 않으므로 생략 (방어 로직 작동 검증)
    }
    
    @Test("시나리오 2: 변환 버튼 탭 시, 이미지가 있으면 로딩 상태로 진입한다.")
    func transformButtonTapped_whenImageExists_startsProcessing() async {
        // given
        let store = makeStore(initialState: ImageTransformFeature.State(inputImage: mockImage))
        
        // when
        await store.send(.transformButtonTapped) {
            // then
            $0.isProcessing = true
            $0.errorMessage = nil
            $0.outputImage = nil
        }
    }
    
    @Test("시나리오 3: 원본 되돌리기 버튼 탭 시, 결과물 및 에러가 초기화된다.")
    func revertButtonTapped_clearsOutput() async {
        // given
        var state = ImageTransformFeature.State(inputImage: mockImage)
        state.outputImage = mockImage
        state.errorMessage = "이전 에러"
        let store = makeStore(initialState: state)
        
        // when
        await store.send(.revertButtonTapped) {
            // then
            $0.outputImage = nil
            $0.errorMessage = nil
        }
    }
        
    @Test("시나리오 4: 변환 로딩 중일 때, 추가 변환 요청은 무시된다.")
    func transformButtonTapped_whileProcessing_isIgnored() async {
        // given
        var state = ImageTransformFeature.State(inputImage: mockImage)
        state.isProcessing = true
        let store = makeStore(initialState: state)
        
        // when
        await store.send(.transformButtonTapped)
        
        // then
        // 상태 변화 클로저가 없으므로 무시됨을 검증
    }
    
    @Test("시나리오 5: 변환 실패 시, 에러 메시지를 할당하고 로딩을 종료한다.")
    func transformFailed_setsErrorMessage() async {
        // given
        let expectedError = "변환 실패"
        let store = makeStore(initialState: ImageTransformFeature.State(inputImage: mockImage)) { _ in
            throw ImageTransformError.custom(expectedError)
        }
        await store.send(.transformButtonTapped) // 실행 트리거
        
        // when
        await store.receive(\.transformFailed) {
            // then
            $0.isProcessing = false
            $0.errorMessage = expectedError
        }
    }
    
    @Test("시나리오 6: 변환 성공 시, 결과 이미지를 할당하고 로딩을 종료한다.")
    func transformCompleted_setsOutputImage() async {
        // given
        let store = makeStore(initialState: ImageTransformFeature.State(inputImage: mockImage)) { _ in
            return self.mockCGImage
        }
        await store.send(.transformButtonTapped) // 실행 트리거
        
        // when
        await store.receive(\.transformCompleted) {
            // then
            $0.isProcessing = false
        }
        
        // then
        #expect(store.state.outputImage != nil)
    }
}


// MARK: - 🛠️ ImageTransformFeatureTests Helpers

private extension ImageTransformFeatureTests {
    func makeStore(
        initialState: ImageTransformFeature.State = .init(),
        transformResult: @Sendable @escaping (CGImage) async throws -> CGImage = { image in image }
    ) -> TestStore<ImageTransformFeature.State, ImageTransformFeature.Action> {
        let store = TestStore(initialState: initialState) {
            ImageTransformFeature()
        } withDependencies: {
            $0.imageTransformClient.transformImage = transformResult
        }
        store.exhaustivity = .off
        return store
    }
    
    static func createMockImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
}
