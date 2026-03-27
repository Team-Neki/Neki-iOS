//
//  ImagePickerFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import ComposableArchitecture
import SwiftUI
import PhotosUI
import ImageIO

@Reducer
public struct ImagePickerFeature {
    public init() {}
    
    @ObservableState
    public struct State {
        public var maxCount: Int
        public let mediaType: ImageMediaType
        
        public var selectedImages: IdentifiedArrayOf<ImageUploadEntity> = []
        public var pickerItems: [PhotosPickerItem] = []
        public var isLoading: Bool = false
        
        public var remainingCount: Int { max(.zero, maxCount - selectedImages.count) }
        
        public init(maxCount: Int = 10, mediaType: ImageMediaType) {
            self.maxCount = maxCount
            self.mediaType = mediaType
        }
    }
    
    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // User Action
        case pickerItemsChanged([PhotosPickerItem])
        
        // Internal Action (Data Load Complete)
        case imageConverted([ImageUploadEntity])
        
        // Upload Action
        case requestUpload
        case uploadStarted
        case uploadCompleted([Int])
        case uploadFailed
    }
    
    @Dependency(\.imageUploadClient) var imageUploadClient
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                
            case let .pickerItemsChanged(items):
                state.pickerItems = items
                guard items.isEmpty == false else { return .none }
                state.isLoading = true
                
                return .run { send in
                    let entities = await Self.convert(items: items)
                    await send(.imageConverted(entities))
                }
                
            case let .imageConverted(newEntities):
                let remaining = state.remainingCount
                if remaining > 0 { state.selectedImages.append(contentsOf: newEntities.prefix(remaining)) }
                
                state.pickerItems.removeAll()
                return .send(.requestUpload)
                
            case .requestUpload:
                guard !state.selectedImages.isEmpty else {
                    state.isLoading = false
                    return .none
                }
                state.isLoading = true
                
                let items = state.selectedImages.elements
                let type = state.mediaType
                
                return .run { send in
                    do {
                        await send(.uploadStarted)
                        let result = try await imageUploadClient.upload(items, type)
                        await send(.uploadCompleted(result))
                    } catch {
                        await send(.uploadFailed)
                    }
                }
                
            case .uploadCompleted, .uploadFailed:
                state.isLoading = false
                state.selectedImages.removeAll()
                return .none
                
            case .binding:
                return .none
                
            default:
                return .none
                
            }
        }
    }
}


// MARK: - ImagePickerFeature Private Func

private extension ImagePickerFeature {
    static func convert(items: [PhotosPickerItem]) async -> [ImageUploadEntity] {
        await withTaskGroup(of: ImageUploadEntity?.self) { group in
            for item in items {
                group.addTask {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
                    let dimensions = extractDimensions(from: data)
                    let format = detectFormat(from: data)
                    
                    return ImageUploadEntity(
                        data: data,
                        format: format,
                        width: dimensions?.width,
                        height: dimensions?.height,
                        size: data.count
                    )
                }
            }
            
            var results: [ImageUploadEntity] = []
            for await result in group {
                guard let result else { continue }
                results.append(result)
            }
            return results
        }
    }
    
    static func detectFormat(from data: Data) -> ImageFileFormat {
        // 데이터가 너무 짧으면 기본값(JPEG) 반환
        guard data.count > 12 else { return .jpeg }
        
        let header = data.prefix(12)
        let firstByte = header[0]
        
        // PNG 확인 (0x89로 시작)
        if firstByte == 0x89 {
            return .png
        }
        
        // WebP 확인
        // WebP 파일 구조:
        // Offset 0-3: "RIFF" (0x52, 0x49, 0x46, 0x46)
        // Offset 8-11: "WEBP" (0x57, 0x45, 0x42, 0x50)
        if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 && // "RIFF"
            header[8] == 0x57 && header[9] == 0x45 && header[10] == 0x42 && header[11] == 0x50 { // "WEBP"
            return .webp
        }
        
        // 나머지는 JPEG로
        return .jpeg
    }
    
    static func extractDimensions(from data: Data) -> (width: Int, height: Int)? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options as CFDictionary) as? [CFString: Any] else {
            return nil
        }
        
        var width = properties[kCGImagePropertyPixelWidth] as? Int
        var height = properties[kCGImagePropertyPixelHeight] as? Int
        
        if let w = width, let h = height { return (w, h) }
        return nil
    }
}
