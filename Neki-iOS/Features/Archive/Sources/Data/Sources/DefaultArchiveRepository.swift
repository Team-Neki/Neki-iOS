//
//  DefaultArchiveRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 1/25/26.
//

import Dependencies
import Foundation

final actor DefaultArchiveRepository: ArchiveRepository {
    @Dependency(\.networkProvider) private var networkProvider

    private var photosByID: [Int: PhotoEntity] = [:]
    private var photoReferenceCounts: [Int: Int] = [:]
    private var pagesByScope: [ArchivePhotoScope: PhotoPageState] = [:]
    private var inFlightRequests: [PhotoRequestKey: Task<PhotoPagePayload, Error>] = [:]

    private var albumCache: [AlbumEntity] = []
    private var favoriteAlbumInfoCache: FavoriteAlbumEntity?
    private var isAlbumCacheDirty = true
    private var isFavoriteAlbumInfoDirty = true
}

// MARK: - Cache Types

private extension DefaultArchiveRepository {
    struct PhotoPageState {
        var orderedIDs: [Int] = []
        var knownIDs: Set<Int> = []
        var loadedPages: Set<Int> = []
        var nextPage = 0
        var hasNext = true
        var totalCount = 0
        var sortOrder: ArchivePhotoSortOrder?
        var isDirty = true
        var generation = 0
    }

    struct PhotoRequestKey: Hashable {
        let scope: ArchivePhotoScope
        let page: Int
        let size: Int?
        let sortOrder: ArchivePhotoSortOrder?
        let generation: Int
    }

    struct PhotoPagePayload: Sendable {
        let photos: [PhotoEntity]
        let hasNext: Bool
        let totalCount: Int
    }
}

// MARK: - Create

extension DefaultArchiveRepository {
    func registerPhoto(
        folderID: Int?,
        uploads: [(mediaID: Int, memo: String?, uploadMethod: PhotoUploadMethod)],
        favorite: Bool? = false
    ) async throws {
        let uploadData = uploads.map {
            RegisterPhotoDTO.RegisterPhotoData(
                mediaID: $0.mediaID,
                memo: $0.memo,
                uploadMethod: $0.uploadMethod.rawValue
            )
        }
        let request = RegisterPhotoDTO.Request(folderID: folderID, uploads: uploadData, favorite: favorite)
        let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: ArchiveEndpoint.registerPhoto(request: request))

        markPhotoScopeDirty(.all)
        if let folderID {
            markPhotoScopeDirty(.album(folderID))
            isAlbumCacheDirty = true
        }
        if favorite == true {
            markPhotoScopeDirty(.favorites)
            isFavoriteAlbumInfoDirty = true
        }
    }

    func addFolder(name: String) async throws -> Int {
        let request = FolderDTO.Request(name: name)
        let result: BaseResponseDTO<FolderDTO.Response> = try await performRequest(endpoint: ArchiveEndpoint.addFolder(request: request))
        guard let data = result.data else { throw NetworkError.responseDecodingError }
        isAlbumCacheDirty = true
        return data.folderId
    }
}

// MARK: - Read

extension DefaultArchiveRepository {
    func refreshPhotos(
        scope: ArchivePhotoScope,
        size: Int?,
        sortOrder: ArchivePhotoSortOrder?
    ) async throws -> ArchivePhotoSnapshot {
        if let pageState = pagesByScope[scope],
           pageState.isDirty == false,
           pageState.sortOrder == sortOrder {
            let hasCachedResult = pageState.orderedIDs.isEmpty == false || pageState.loadedPages.isEmpty == false
            let hasInFlightRequest = inFlightRequests.keys.contains { $0.scope == scope && $0.generation == pageState.generation }
            if hasCachedResult { return snapshot(for: scope) }
            if hasInFlightRequest { return try await fetchPage(scope: scope, size: size, sortOrder: sortOrder) }
        }
        resetPhotoPage(for: scope, sortOrder: sortOrder)
        return try await fetchPage(scope: scope, size: size, sortOrder: sortOrder)
    }

    func fetchNextPhotos(
        scope: ArchivePhotoScope,
        size: Int?,
        sortOrder: ArchivePhotoSortOrder?
    ) async throws -> ArchivePhotoSnapshot {
        let pageState = pagesByScope[scope] ?? PhotoPageState()
        guard pageState.isDirty == false,
              pageState.orderedIDs.isEmpty == false,
              pageState.sortOrder == sortOrder
        else {
            return try await refreshPhotos(scope: scope, size: size, sortOrder: sortOrder)
        }
        guard pageState.hasNext else { return snapshot(for: scope) }
        return try await fetchPage(scope: scope, size: size, sortOrder: sortOrder)
    }

    func getAlbumList() async throws -> [AlbumEntity] {
        if isAlbumCacheDirty == false, albumCache.isEmpty == false { return albumCache }

        let result: BaseResponseDTO<AlbumInfoDTO> = try await performRequest(endpoint: ArchiveEndpoint.getAlbumList)
        guard let data = result.data else { throw NetworkError.responseDecodingError }

        albumCache = data.items.map {
            AlbumEntity(
                id: $0.folderID,
                name: $0.name,
                photoCount: $0.totalCount,
                coverImageURLString: $0.latestImageURL ?? ""
            )
        }
        isAlbumCacheDirty = false
        return albumCache
    }

    func getFavoriteAlbumInfo() async throws -> FavoriteAlbumEntity {
        if isFavoriteAlbumInfoDirty == false, let favoriteAlbumInfoCache { return favoriteAlbumInfoCache }

        let result: BaseResponseDTO<FavoriteAlbumInfoDTO> = try await performRequest(endpoint: ArchiveEndpoint.getFavoriteAlbumInfo)
        guard let data = result.data else { throw NetworkError.responseDecodingError }

        let entity = FavoriteAlbumEntity(
            latestImageURL: data.latestImageURL ?? "",
            totalCount: data.totalCount
        )
        favoriteAlbumInfoCache = entity
        isFavoriteAlbumInfoDirty = false
        return entity
    }
}

// MARK: - Update

extension DefaultArchiveRepository {
    func toggleFavorite(photoID: Int, request: Bool) async throws {
        let dto = ToggleFavoriteDTO(favorite: request)
        let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: ArchiveEndpoint.toggleFavorite(photoID: photoID, request: dto))

        photosByID[photoID]?.isFavorite = request
        markPhotoScopeDirty(.favorites)
        isFavoriteAlbumInfoDirty = true
    }

    func excludePhotosInAlbum(albumID: Int, photoIDs: [Int]) async throws {
        let request = DeletePhotoRequestDTO(photoIds: photoIDs)
        let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: ArchiveEndpoint.excludePhotosInAlbum(albumID: albumID, request: request))
        isAlbumCacheDirty = true
        markPhotoScopeDirty(.album(albumID))
    }

    func editAlbumName(albumID: Int, name: String) async throws {
        let request = FolderDTO.Request(name: name)
        let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: ArchiveEndpoint.editFolderName(albumID: albumID, request: request))
        isAlbumCacheDirty = true
    }

    func updatePhotoMemo(photoID: Int, memo: String) async throws {
        let capturedAt = photosByID[photoID]?.createdAtRawValue ?? Date().ISO8601Format()
        let request = UpdateMemoRequestDTO(memo: memo, capturedAt: capturedAt)
        let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: ArchiveEndpoint.updateMemo(photoID: photoID, request: request))
        photosByID[photoID]?.memo = memo
    }

    func duplicatePhoto(photoIDs: [Int], targetFolderIDs: [Int]) async throws {
        let request = UpdateMappingPhotoDTO.DuplicatePhotos(
            photoIDs: photoIDs,
            targetFolderIDs: targetFolderIDs
        )
        let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: ArchiveEndpoint.duplicatePhoto(request: request))

        isAlbumCacheDirty = true
        targetFolderIDs.forEach { markPhotoScopeDirty(.album($0)) }
    }

    func movePhoto(sourceFolderId: Int, photoIDs: [Int], targetFolderIDs: [Int]) async throws {
        let request = UpdateMappingPhotoDTO.MovePhotos(
            sourceFolderID: sourceFolderId,
            photoIDs: photoIDs,
            targetFolderIDs: targetFolderIDs
        )
        let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: ArchiveEndpoint.movePhoto(request: request))

        isAlbumCacheDirty = true
        markPhotoScopeDirty(.album(sourceFolderId))
        targetFolderIDs.forEach { markPhotoScopeDirty(.album($0)) }
    }
}

// MARK: - Delete

extension DefaultArchiveRepository {
    func deletePhotoList(photoIDs: [Int]) async throws {
        let request = DeletePhotoRequestDTO(photoIds: photoIDs)
        let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: ArchiveEndpoint.deletePhoto(request: request))

        let deletedIDs = Set(photoIDs)
        var affectedScopes = Set(pagesByScope.keys)
        affectedScopes.insert(.all)
        affectedScopes.insert(.favorites)
        affectedScopes.forEach { scope in
            removePhotoIDs(deletedIDs, from: scope)
            markPhotoScopeDirty(scope)
        }
        deletedIDs.forEach { photosByID.removeValue(forKey: $0) }
        isAlbumCacheDirty = true
        isFavoriteAlbumInfoDirty = true
    }

    func deleteFolders(folderIDs: [Int], deletePhotos: Bool) async throws {
        let request = DeleteFoldersRequestDTO(folderIds: folderIDs)
        let _: BaseResponseDTO<EmptyData> = try await performRequest(endpoint: ArchiveEndpoint.deleteFolders(request: request, deletePhotos: deletePhotos))

        isAlbumCacheDirty = true
        folderIDs.forEach { removePhotoPage(for: .album($0)) }
        guard deletePhotos else { return }
        markPhotoScopeDirty(.all)
        markPhotoScopeDirty(.favorites)
        isFavoriteAlbumInfoDirty = true
    }

    func clearCache() async throws {
        inFlightRequests.values.forEach { $0.cancel() }
        inFlightRequests.removeAll()
        photosByID.removeAll()
        photoReferenceCounts.removeAll()
        pagesByScope.removeAll()
        albumCache.removeAll()
        favoriteAlbumInfoCache = nil
        isAlbumCacheDirty = true
        isFavoriteAlbumInfoDirty = true
    }
}

// MARK: - Request Mapping

private extension DefaultArchiveRepository {
    func performRequest<Response: Decodable>(endpoint: ArchiveEndpoint) async throws -> BaseResponseDTO<Response> {
        do { return try await networkProvider.request(endpoint: endpoint) }
        catch NetworkError.unauthorizedError { throw ArchiveRequestError.authenticationRequired }
    }
}


// MARK: - Photo Cache

private extension DefaultArchiveRepository {
    func fetchPage(
        scope: ArchivePhotoScope,
        size: Int?,
        sortOrder: ArchivePhotoSortOrder?
    ) async throws -> ArchivePhotoSnapshot {
        var pageState = pagesByScope[scope] ?? PhotoPageState()
        let page = pageState.nextPage
        let requestKey = PhotoRequestKey(
            scope: scope,
            page: page,
            size: size,
            sortOrder: sortOrder,
            generation: pageState.generation
        )

        if pageState.loadedPages.contains(page) { return snapshot(for: scope) }

        let requestTask: Task<PhotoPagePayload, Error>
        if let inFlightRequest = inFlightRequests[requestKey] {
            requestTask = inFlightRequest
        } else {
            requestTask = Task {
                try await self.requestPhotoPage(
                    scope: scope,
                    page: page,
                    size: size,
                    sortOrder: sortOrder
                )
            }
            inFlightRequests[requestKey] = requestTask
        }

        do {
            let payload = try await requestTask.value
            inFlightRequests[requestKey] = nil

            pageState = pagesByScope[scope] ?? PhotoPageState()
            guard pageState.generation == requestKey.generation else { return snapshot(for: scope) }
            guard pageState.loadedPages.contains(page) == false else { return snapshot(for: scope) }

            payload.photos.forEach { photosByID[$0.id] = $0 }
            payload.photos.forEach {
                guard pageState.knownIDs.insert($0.id).inserted else { return }
                pageState.orderedIDs.append($0.id)
                photoReferenceCounts[$0.id, default: 0] += 1
            }
            pageState.loadedPages.insert(page)
            pageState.hasNext = payload.hasNext
            pageState.totalCount = payload.totalCount
            pageState.sortOrder = sortOrder
            pageState.isDirty = false
            if payload.hasNext { pageState.nextPage = page + 1 }
            pagesByScope[scope] = pageState
            return snapshot(for: scope)
        } catch {
            inFlightRequests[requestKey] = nil
            throw error
        }
    }

    func requestPhotoPage(
        scope: ArchivePhotoScope,
        page: Int,
        size: Int?,
        sortOrder: ArchivePhotoSortOrder?
    ) async throws -> PhotoPagePayload {
        let request = PhotoListDTO.Request(
            folderId: scope.folderID,
            page: page,
            size: size,
            sortOrder: sortOrder?.rawValue
        )
        let endpoint: ArchiveEndpoint = scope == .favorites
            ? .getFavoritePhotoList(request: request)
            : .getPhotoList(request: request)
        let response: BaseResponseDTO<PhotoListDTO.PhotoListData> = try await performRequest(endpoint: endpoint)
        guard let data = response.data else { throw NetworkError.responseDecodingError }
        var photos = data.toEntity()
        if scope == .favorites {
            photos.indices.forEach { photos[$0].isFavorite = true }
        }
        return PhotoPagePayload(
            photos: photos,
            hasNext: data.hasNext,
            totalCount: data.totalCount
        )
    }

    func snapshot(for scope: ArchivePhotoScope) -> ArchivePhotoSnapshot {
        let pageState = pagesByScope[scope] ?? PhotoPageState()
        return ArchivePhotoSnapshot(
            photos: pageState.orderedIDs.compactMap { photosByID[$0] },
            totalCount: pageState.totalCount,
            hasNext: pageState.hasNext
        )
    }

    func resetPhotoPage(
        for scope: ArchivePhotoScope,
        sortOrder: ArchivePhotoSortOrder?
    ) {
        let nextGeneration = (pagesByScope[scope]?.generation ?? 0) + 1
        cancelRequests(for: scope)
        releasePhotoReferences(pagesByScope[scope]?.orderedIDs ?? [])
        pagesByScope[scope] = PhotoPageState(
            sortOrder: sortOrder,
            isDirty: false,
            generation: nextGeneration
        )
    }

    func markPhotoScopeDirty(_ scope: ArchivePhotoScope) {
        var pageState = pagesByScope[scope] ?? PhotoPageState()
        pageState.isDirty = true
        pageState.generation += 1
        pagesByScope[scope] = pageState
        cancelRequests(for: scope)
    }

    func removePhotoIDs(_ photoIDs: Set<Int>, from scope: ArchivePhotoScope) {
        guard var pageState = pagesByScope[scope] else { return }
        let removedIDs = photoIDs.intersection(pageState.knownIDs)
        pageState.orderedIDs.removeAll { photoIDs.contains($0) }
        pageState.knownIDs.subtract(photoIDs)
        pagesByScope[scope] = pageState
        releasePhotoReferences(removedIDs)
    }

    func removePhotoPage(for scope: ArchivePhotoScope) {
        cancelRequests(for: scope)
        releasePhotoReferences(pagesByScope[scope]?.orderedIDs ?? [])
        pagesByScope[scope] = nil
    }

    func cancelRequests(for scope: ArchivePhotoScope) {
        let requestKeys = inFlightRequests.keys.filter { $0.scope == scope }
        requestKeys.forEach {
            inFlightRequests[$0]?.cancel()
            inFlightRequests[$0] = nil
        }
    }

    func releasePhotoReferences<S: Sequence>(_ photoIDs: S) where S.Element == Int {
        photoIDs.forEach { photoID in
            guard let referenceCount = photoReferenceCounts[photoID] else { return }
            guard referenceCount > 1 else {
                photoReferenceCounts[photoID] = nil
                photosByID[photoID] = nil
                return
            }
            photoReferenceCounts[photoID] = referenceCount - 1
        }
    }
}

// MARK: - Dependency

private enum ArchiveRepositoryKey: DependencyKey {
    static let liveValue: ArchiveRepository = DefaultArchiveRepository()
}

extension DependencyValues {
    var archiveRepository: ArchiveRepository {
        get { self[ArchiveRepositoryKey.self] }
        set { self[ArchiveRepositoryKey.self] = newValue }
    }
}
