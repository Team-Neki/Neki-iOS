//
//  DefaultArchiveRepository.swift
//  Neki-iOS
//
//  Created by OneTen on 1/25/26.
//

import Foundation
import Dependencies

final actor DefaultArchiveRepository: ArchiveRepository {
    
    @Dependency(\.networkProvider) var networkProvider
    
    // MARK: - Cache
    
    private var photoCache: [Int?: [PhotoEntity]] = [:] // 사진들 캐시(앨범별), 앨범을 nil로 줄 경우 전체 사진
    private var currentSortOrder: [Int?: String] = [:]  // 앨범별 정렬 (최신순, 오래된 순)

    private var albumCache: [AlbumEntity] = []  // 앨범들 정보 캐시
    private var favoritePhotoCache: [PhotoEntity] = []  // 즐겨찾기 사진들 캐시
    private var favoriteAlbumInfoCache: FavoriteAlbumEntity?    // 즐겨찾기 앨범 정보 캐시
    
    
    // Dirty Flags (데이터 유효성 검사)
    private var isPhotoCacheDirty: [Int?: Bool] = [:]   // 사진 변경사항 플래그
    private var isAlbumCacheDirty: Bool = true  // 앨범 변경사항 플래그
    private var isFavoriteCacheDirty: Bool = true   // 즐겨찾는 사진 변경사항 플래그
    private var isFavoriteAlbumInfoDirty: Bool = true   // 즐겨찾기 앨범 정보 변경사항 플래그
    
    
    // MARK: - Pagination State
    
    private var currentPhotoPage: [Int?: Int] = [:]
    private var hasNextPhoto: [Int?: Bool] = [:]
    private var currentFavoritePage: Int = 0
    private var hasNextFavorite: Bool = true
}


// MARK: - Create Logic

extension DefaultArchiveRepository {
    func registerPhoto(folderID: Int?, uploads: [(mediaID: Int, memo: String?)]) async throws {
        let uploadData = uploads.map { RegisterPhotoDTO.RegisterPhotoData(mediaID: $0.mediaID, memo: $0.memo) }
        let request = RegisterPhotoDTO.Request(folderID: folderID, uploads: uploadData)
        let endpoint = ArchiveEndpoint.registerPhoto(request: request)
        let _ = try await networkProvider.request(endpoint: endpoint)
        
        
        self.isPhotoCacheDirty[nil] = true  // 전체 사진 캐시에 변경 신호
        if let folderID = folderID {        // 앨범을 선택해 업로드 했다면 해당 앨범내 사진 캐시와 전체 앨범 캐시에도 변경 신호
            self.isPhotoCacheDirty[folderID] = true
            self.isAlbumCacheDirty = true
        }
    }
    
    func addFolder(name: String) async throws -> Int {
        let request = AddFolderDTO.Request(name: name)
        let result: BaseResponseDTO<AddFolderDTO.Response> = try await networkProvider.request(endpoint: ArchiveEndpoint.addFolder(request: request))
        guard let data = result.data else { throw NetworkError.responseDecodingError }
        
        self.isAlbumCacheDirty = true
        return data.folderId
    }
}


// MARK: - Read Logic

extension DefaultArchiveRepository {
    
    func fetchPhotoList(folderID: Int?, size: Int?, sortOrder: String?) async throws -> [PhotoEntity] {
        
        /// 캐시가 더렵혀졌거나(변경사항이 있거나) 비어있으면 실행
        /// 첫 페이지부터 다시 불러오고 기존에 저장되어 있던 캐시들 삭제
        let isDirty = isPhotoCacheDirty[folderID] ?? true
        let currentCache = photoCache[folderID] ?? []
        
        // 요청한 정렬 순서 (기본값 DESC)
        let requestSortOrder = sortOrder ?? "DESC"
        // 기존에 저장된 정렬 순서
        let cachedSortOrder = currentSortOrder[folderID]
        // 정렬이 바뀌었으면 무조건 Dirty로 간주하여 초기화
        let isSortChanged = (cachedSortOrder != nil) && (cachedSortOrder != requestSortOrder)
        
        if isDirty || currentCache.isEmpty || isSortChanged {
            currentPhotoPage[folderID] = 0
            hasNextPhoto[folderID] = true
            photoCache[folderID] = []
            isPhotoCacheDirty[folderID] = false
            currentSortOrder[folderID] = requestSortOrder
        }
        
        // 마지막 페이지면 실행
        if let hasNext = hasNextPhoto[folderID], !hasNext {
            return photoCache[folderID] ?? []
        }
        
        let page = currentPhotoPage[folderID] ?? 0
        let request = PhotoListDTO.Request(folderId: folderID, page: page, size: size ?? 20, sortOrder: sortOrder)
        let endpoint = ArchiveEndpoint.getPhotoList(request: request)
        let response: BaseResponseDTO<PhotoListDTO.PhotoListData> = try await networkProvider.request(endpoint: endpoint)
        
        guard let data = response.data else { throw NetworkError.responseDecodingError }
        
        let newEntities = data.toEntity()
        
        /// 캐시 업데이트 (해당 폴더 Key에 추가)
        /// 테스트해보니 라이프사이클 시점 문제인지 같은 아이디의 사진을 받고 있어서 앱이 꺼지는 현상 발견
        /// 따라서 캐시에 존재하는 값들을 set으로 만든 후 새로운 데이터와 비교해 없는 값만 캐시에 추가
        var currentList = photoCache[folderID] ?? []
        let existingIDs = Set(currentList.map { $0.photoID })
        
        // 새로운 데이터 중 기존에 없는 것만 필터링
        let uniqueNewEntities = newEntities.filter { !existingIDs.contains($0.photoID) }
        
        // 중복 없는 데이터만 추가
        currentList.append(contentsOf: uniqueNewEntities)
        
        photoCache[folderID] = currentList
        
        // 페이지 상태 업데이트
        hasNextPhoto[folderID] = data.hasNext
        if data.hasNext {
            currentPhotoPage[folderID] = page + 1
        }
        
        return currentList
    }
    
    func getAlbumList() async throws -> [AlbumEntity] {
        // 캐시에 변경사항이 없고, 비어있지도 않으면 캐시된 값 리턴
        if !isAlbumCacheDirty, !albumCache.isEmpty {
            return albumCache
        }
        
        let result: BaseResponseDTO<AlbumInfoDTO> = try await networkProvider.request(endpoint: ArchiveEndpoint.getAlbumList)
        guard let data = result.data else { throw NetworkError.responseDecodingError }
        
        let entities: [AlbumEntity] = data.items.map {
            AlbumEntity(id: $0.folderID, name: $0.name, photoCount: $0.totalCount, coverImageURLString: $0.latestImageURL ?? "")
        }
        
        self.albumCache = entities
        self.isAlbumCacheDirty = false
        
        return entities
    }
    
    func getFavoriteAlbumInfo() async throws -> FavoriteAlbumEntity {
        if !isFavoriteAlbumInfoDirty, let cache = favoriteAlbumInfoCache {
            return cache
        }
        
        let result: BaseResponseDTO<FavoriteAlbumInfoDTO> = try await networkProvider.request(endpoint: ArchiveEndpoint.getFavoriteAlbumInfo)
        guard let data = result.data else { throw NetworkError.responseDecodingError }
        
        let entity = FavoriteAlbumEntity(latestImageURL: data.latestImageURL ?? "", totalCount: data.totalCount)
        
        self.favoriteAlbumInfoCache = entity
        self.isFavoriteAlbumInfoDirty = false
        
        return entity
    }
    
    func fetchFavoritePhotoList(size: Int?, sortOrder: String?) async throws -> [PhotoEntity] {
        
        if isFavoriteCacheDirty || favoritePhotoCache.isEmpty {
            currentFavoritePage = 0
            hasNextFavorite = true
            favoritePhotoCache.removeAll()
            isFavoriteCacheDirty = false
        }
        
        if !hasNextFavorite { return favoritePhotoCache }
        
        let request = PhotoListDTO.Request(folderId: nil, page: currentFavoritePage, size: size ?? 20, sortOrder: sortOrder)
        let endpoint = ArchiveEndpoint.getFavoritePhotoList(request: request)
        let response: BaseResponseDTO<PhotoListDTO.PhotoListData> = try await networkProvider.request(endpoint: endpoint)
        
        guard let data = response.data else { throw NetworkError.responseDecodingError }
        
        let newEntities = data.toEntity()
        let existingIDs = Set(self.favoritePhotoCache.map { $0.photoID })
        let uniqueNewEntities = newEntities.filter { !existingIDs.contains($0.photoID) }
        
        self.favoritePhotoCache.append(contentsOf: uniqueNewEntities)
        
        self.hasNextFavorite = data.hasNext
        if data.hasNext { self.currentFavoritePage += 1 }
        
        return self.favoritePhotoCache
    }
}


// MARK: - Update Logic

extension DefaultArchiveRepository {
    
    func toggleFavorite(photoID: Int, request: Bool) async throws {
        let dto = ToggleFavoriteDTO(favorite: request)
        let endpoint = ArchiveEndpoint.toggleFavorite(photoID: photoID, request: dto)
        
        do {
            let _ = try await networkProvider.request(endpoint: endpoint)
            
            for (key, var list) in photoCache {
                if let index = list.firstIndex(where: { $0.photoID == photoID }) {
                    let oldItem = list[index]
                    let newItem = PhotoEntity(
                        photoID: oldItem.photoID,
                        imageURL: oldItem.imageURL,
                        folderID: oldItem.folderID,
                        isfavorite: request,
                        contentType: oldItem.contentType,
                        createdAt: oldItem.createdAt
                    )
                    list[index] = newItem
                    photoCache[key] = list
                }
            }
            
            self.isFavoriteCacheDirty = true
            self.isFavoriteAlbumInfoDirty = true
        } catch {
            throw error
        }
    }
    
    func excludePhotosInAlbum(albumID: Int, photoIDs: [Int]) async throws {
        let request = DeletePhotoRequestDTO(photoIds: photoIDs)
        let endpoint = ArchiveEndpoint.excludePhotosInAlbum(albumID: albumID, request: request)
        let _ = try await networkProvider.request(endpoint: endpoint)
        
        self.isAlbumCacheDirty = true
        self.isPhotoCacheDirty[albumID] = true
    }
}


// MARK: - Delete Logic

extension DefaultArchiveRepository {
    func deletePhotoList(photoIDs: [Int]) async throws {
        let request = DeletePhotoRequestDTO(photoIds: photoIDs)
        let endpoint = ArchiveEndpoint.deletePhoto(request: request)
        let _ = try await networkProvider.request(endpoint: endpoint)
        
        for (key, var list) in photoCache {
            list.removeAll { photoIDs.contains($0.photoID) }
            photoCache[key] = list
        }
        
        self.isAlbumCacheDirty = true
        self.isFavoriteCacheDirty = true
        self.isFavoriteAlbumInfoDirty = true
    }
    
    func deleteFolders(folderIDs: [Int], deletePhotos: Bool) async throws {
        let request = DeleteFoldersRequestDTO(folderIds: folderIDs)
        let endpoint = ArchiveEndpoint.deleteFolders(request: request, deletePhotos: deletePhotos)
        let _ = try await networkProvider.request(endpoint: endpoint)
        
        self.isAlbumCacheDirty = true
        
        for folderID in folderIDs {
            self.photoCache.removeValue(forKey: folderID)
            self.currentPhotoPage.removeValue(forKey: folderID)
            self.hasNextPhoto.removeValue(forKey: folderID)
            self.isPhotoCacheDirty.removeValue(forKey: folderID)
        }
        
        if deletePhotos {
            self.isPhotoCacheDirty[nil] = true
            self.isFavoriteCacheDirty = true
            self.isFavoriteAlbumInfoDirty = true
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
