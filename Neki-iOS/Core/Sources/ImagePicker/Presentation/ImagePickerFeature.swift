//
//  ImagePickerFeature.swift
//  Neki-iOS
//
//  Created by OneTen on 1/22/26.
//

import ComposableArchitecture
import SwiftUI
import PhotosUI

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
        case uploadReady([ImageUploadEntity])
        
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
                state.isLoading = true
                
                return .run { send in
                    
                    let entities = await withTaskGroup(of: ImageUploadEntity?.self) { group in
                        for (index, item) in items.enumerated() {
                            group.addTask {
                                guard let data = try? await item.loadTransferable(type: Data.self) else {
                                    return nil
                                }
                                
                                let format = data.detectedImageFormat
                                let entity = ImageUploadEntity(data: data, format: format)
                                
                                return entity
                            }
                        }
                        
                        var results: [ImageUploadEntity] = []
                        
                        for await result in group {
                            if let result { results.append(result) }
                        }
                        
                        return results
                    }
                    await send(.uploadReady(entities))
                }
                
            case let .uploadReady(newEntities):
                let remaining = state.maxCount - state.selectedImages.count
                if remaining > 0 {
                    state.selectedImages.append(contentsOf: newEntities.prefix(remaining))
                }
                
                state.pickerItems.removeAll()
                
                return .send(.requestUpload)
                
            case .requestUpload:
                guard !state.selectedImages.isEmpty else {
                    return .send(.uploadCompleted([]))
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
