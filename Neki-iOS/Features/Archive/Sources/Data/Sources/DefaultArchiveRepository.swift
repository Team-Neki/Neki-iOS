//
//  DefaultArchiveRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 1/25/26.
//

import Foundation
import Dependencies

struct DefaultArchiveRepository: ArchiveRepository {
    @Dependency(\.networkProvider) var networkProvider
    
    func fetchPhotoList(folderID: Int?, page: Int?, size: Int?, sortOrder: String?) async throws -> (photos: [PhotoEntity], hasNext: Bool) {
        let request = PhotoListDTO.Request(folderId: folderID, page: page, size: size, sortOrder: sortOrder)
        let endpoint = ArchiveEndpoint.getPhotoList(request: request)
        let response: BaseResponseDTO<PhotoListDTO.PhotoListData> = try await networkProvider.request(endpoint: endpoint)
        
        guard let data = response.data else { throw NetworkError.responseDecodingError }
        
        let entities = data.toEntity()
        
        return (entities, data.hasNext)
    }
    
    func deletePhotoList(photoIDs: [Int]) async throws {
        let request = DeletePhotoRequestDTO(photoIds: photoIDs)
        let endpoint = ArchiveEndpoint.deletePhoto(request: request)
        let _ = try await networkProvider.request(endpoint: endpoint)
    }
}

private enum ArchiveRepositoryKey: DependencyKey {
    static let liveValue: ArchiveRepository = DefaultArchiveRepository()
}

extension DependencyValues {
    var archiveRepository: ArchiveRepository {
        get { self[ArchiveRepositoryKey.self] }
        set { self[ArchiveRepositoryKey.self] = newValue }
    }
}
