//
//  PhotoBoothSearchFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/23/26.
//

import Foundation
import CoreLocation
import ComposableArchitecture

@Reducer
public struct PhotoBoothSearchFeature {
    /// 한 종류의 검색 후보를 페이지가 도착한 순서대로 누적하는 상태입니다.
    struct TypePagination: Equatable {
        var candidates: [PhotoBoothSearchCandidate] = []
        var nextPage: Int = PhotoBoothSearchPaging.firstPage
        /// 더 이상 불러올 페이지가 없는지 여부입니다.
        var isExhausted: Bool = false
        /// 이미 담은 후보의 식별자입니다. 페이지 사이의 중복을 걸러내는 데 씁니다.
        private var candidateIDs: Set<PhotoBoothSearchCandidate.ID> = []

        /// 노출할 순서로 세운 한 페이지를 목록 끝에 이어붙이고, 새로 담은 후보가 있는지 알려 줍니다.
        ///
        /// 페이징 도중 서버 데이터가 바뀌면 같은 후보가 두 페이지에 걸쳐 내려올 수 있습니다.
        /// 목록은 후보 식별자로 셀을 구분하므로 중복이 섞이면 화면이 깨져 여기서 걸러냅니다.
        ///
        /// 새로 담을 후보가 없는데 다음 페이지가 있다는 응답은 서로 맞지 않습니다.
        /// 그대로 믿고 같은 종류를 계속 되물으면 요청이 끝나지 않으므로 소진으로 판정합니다.
        mutating func append(_ pageCandidates: [PhotoBoothSearchCandidate], hasNext: Bool) -> Bool {
            let newCandidates = pageCandidates.filter { candidateIDs.insert($0.id).inserted }
            candidates.append(contentsOf: newCandidates)
            nextPage += 1
            isExhausted = hasNext == false || newCandidates.isEmpty
            return newCandidates.isEmpty == false
        }
    }

    /// 검색 결과 목록에 노출할 후보 한 건입니다.
    struct Row: Equatable, Identifiable {
        let candidate: PhotoBoothSearchCandidate
        /// 사용자 현재 위치로부터의 거리(m). 노출하지 않는 경우 `nil`입니다.
        let distance: Int?

        var id: String { candidate.id }
    }

    @ObservableState
    public struct State: Equatable {
        public enum Mode: Equatable {
            case inactive
            case searching
        }

        /// 검색 화면 본문에 노출할 내용입니다.
        public enum ContentState: Equatable {
            /// 검색 전 안내
            case guide
            /// 검색 후보 목록
            case results
            /// 모든 유형에서 결과가 없음
            case noResult
            /// 요청 실패
            case failure(PhotoBoothSearchFailure)
        }

        var mode: Mode = .inactive
        var searchText: String = ""
        var query: PhotoBoothSearchQuery?
        /// 상위 화면(지도)이 전달한 가장 최근의 사용자 현재 위치입니다. 위치 권한에 동의하지 않았으면 `nil`입니다.
        ///
        /// 이 값 자체는 거리 표기에 쓰지 않습니다. 검색을 시작할 때 ``distanceOrigin``으로 옮겨 고정합니다.
        var userCoordinate: GeographicCoordinate?
        /// 거리 표기의 기준으로 고정한 좌표입니다. 검색을 시작한 시점의 현재 위치를 그대로 씁니다.
        ///
        /// 위치는 계속 갱신되지만 그때마다 목록 전체의 거리를 다시 계산하면 낭비이고,
        /// 이미 보고 있는 목록의 거리가 흔들려 읽기도 어렵습니다.
        /// - Note: 검색 중 이동을 거리에 반영할지는 정책이 정해지지 않아, 지금은 검색 시점으로 고정합니다.
        var distanceOrigin: GeographicCoordinate?
        var region = TypePagination()
        var station = TypePagination()
        var photoBooth = TypePagination()
        /// 지역 → 지하철역 → 포토부스 순서로 이어붙인 검색 후보입니다.
        ///
        /// 목록이 길어질 수 있어 페이지가 도착하거나 기준 위치가 바뀔 때만 다시 만듭니다.
        var rows: [Row] = []
        var isFetching: Bool = false
        /// 후보를 선택한 뒤 부스 조회가 진행 중인지 여부입니다.
        var isFetchingSearchResult: Bool = false
        /// 후보 페이지 요청이 실패한 원인입니다.
        var failure: PhotoBoothSearchFailure?
        /// 화면에 띄울 알림입니다. 후보를 선택한 뒤 부스 조회가 실패한 경우에 채웁니다.
        var toast: NekiToastItem?
        var requestGeneration: Int = .zero

        public init() {}

        /// 다음 페이지를 이어서 채울 종류입니다. 세 종류가 모두 소진됐으면 `nil`입니다.
        ///
        /// 정책 순서상 앞선 종류를 모두 소진한 뒤에 다음 종류로 넘어갑니다.
        var pendingType: PhotoBoothSearchCandidateType? {
            PhotoBoothSearchCandidateType.displayOrdered.first { pagination(for: $0).isExhausted == false }
        }

        /// 화면을 덮는 로딩을 노출해야 하는지 여부입니다.
        ///
        /// 첫 화면을 채우는 요청만 화면을 덮고, 목록을 이어붙이는 페이지 요청은 목록을 그대로 둡니다.
        /// 부스 후보는 네트워크 호출 없이 응답하므로 노출 지연 정책에 걸려 로딩이 보이지 않습니다.
        var isLoading: Bool {
            isFetchingSearchResult || (isFetching && rows.isEmpty)
        }

        /// 검색 화면 본문에 노출할 내용입니다.
        ///
        /// 이미 보여준 후보가 있으면 이어지는 페이지가 실패하더라도 목록을 유지합니다.
        /// 후보를 고른 뒤의 조회 실패도 목록을 덮지 않고 ``toast``로만 알립니다.
        var contentState: ContentState {
            guard mode == .searching else { return .guide }
            if rows.isEmpty == false { return .results }
            if let failure { return .failure(failure) }
            return hasNoSearchResult ? .noResult : .guide
        }

        /// 모든 유형에서 검색 결과가 없어 전체 검색 결과 없음 상태를 노출해야 하는지 여부입니다.
        ///
        /// 세 종류를 모두 소진할 때까지는 아직 결과 없음으로 판정하지 않습니다.
        private var hasNoSearchResult: Bool {
            pendingType == nil && isFetching == false && rows.isEmpty
        }

        func pagination(for type: PhotoBoothSearchCandidateType) -> TypePagination {
            switch type {
            case .region: region
            case .subwayStation: station
            case .photoBooth: photoBooth
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case submitSearch
        case beginSearch(PhotoBoothSearchQuery)
        case fetchNextCandidatePage
        case candidatePageResponse(Result<PhotoBoothSearchCandidatePage, Error>, generation: Int)
        case didSelectCandidate(PhotoBoothSearchCandidate)
        case searchResultResponse(Result<PhotoBoothSearchResult, Error>, candidate: PhotoBoothSearchCandidate, generation: Int)
        /// 거리 계산의 기준이 되는 현재 위치를 갱신합니다. 상위 화면(지도)이 전달합니다.
        case setUserCoordinate(GeographicCoordinate?)
        /// 검색 화면을 닫습니다. 상위 화면(지도)이 이 액션을 보고 표시를 해제합니다.
        case dismissSearch
        case delegate(Delegate)

        public enum Delegate: Equatable {
            /// 사용자가 고른 후보와 그 후보로 지도를 다시 그릴 값입니다.
            case didSelectSearchResult(candidate: PhotoBoothSearchCandidate, result: PhotoBoothSearchResult)
        }
    }

    private enum CancelID: Hashable {
        case candidatePage
        case searchResult
    }

    @Dependency(\.photoBoothClient) private var photoBoothClient

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            // 검색어를 모두 지우더라도 새 검색을 제출하기 전까지는 직전 검색 결과를 유지합니다.
            case .binding:
                return .none

            case .submitSearch:
                let keyword = state.searchText
                guard keyword.isEmpty == false else { return .none }
                return .send(.beginSearch(PhotoBoothSearchQuery(rawValue: keyword)))

            case let .beginSearch(query):
                state.beginSearch(query: query)
                return .concatenate(
                    .merge(
                        .cancel(id: CancelID.candidatePage),
                        .cancel(id: CancelID.searchResult)
                    ),
                    .send(.fetchNextCandidatePage)
                )

            case .fetchNextCandidatePage:
                guard state.mode == .searching,
                      state.isFetching == false,
                      let query = state.query,
                      let type = state.pendingType
                else { return .none }
                let page = state.pagination(for: type).nextPage
                let generation = state.requestGeneration
                state.isFetching = true
                // 실패한 뒤 다시 스크롤하면 같은 페이지를 다시 시도합니다.
                state.failure = nil
                return .run { send in
                    do {
                        let response = try await photoBoothClient.searchCandidates(query, type, page)
                        await send(.candidatePageResponse(.success(response), generation: generation))
                    } catch is CancellationError { return } catch {
                        await send(.candidatePageResponse(.failure(error), generation: generation))
                    }
                }
                .cancellable(id: CancelID.candidatePage)

            case let .candidatePageResponse(.success(page), generation):
                guard state.mode == .searching, state.requestGeneration == generation else { return .none }
                state.isFetching = false
                let hasNewCandidates = state.append(page)
                // 새 셀이 생기지 않은 페이지(빈 페이지, 이미 담은 후보만 온 페이지)는
                // 스크롤 트리거가 발생하지 않으므로 다음 종류로 이어 부릅니다.
                guard hasNewCandidates == false, state.pendingType != nil else { return .none }
                return .send(.fetchNextCandidatePage)

            case let .candidatePageResponse(.failure(error), generation):
                guard state.mode == .searching, state.requestGeneration == generation else { return .none }
                state.isFetching = false
                state.failure = PhotoBoothSearchFailure(error)
                return .none

            case let .didSelectCandidate(candidate):
                // 조회 중에는 로딩이 화면을 덮지만, 여러 셀이 한 번에 눌리면 액션이 겹쳐 들어올 수 있어 여기서도 막습니다.
                // 먼저 고른 후보의 조회를 끝까지 살려 두어 나중에 눌린 셀이 결과를 가로채지 않게 합니다.
                guard state.mode == .searching, state.isFetchingSearchResult == false else { return .none }
                state.isFetchingSearchResult = true
                let generation = state.requestGeneration
                // 서버가 사용자 위치를 기준으로 거리를 계산하므로 기준 좌표를 함께 넘깁니다.
                let userCoordinate = state.userCoordinate
                return .run { send in
                    do {
                        // 부스 목록과 필터는 요청 body가 같아 함께 조회하고, 둘 다 도착해야 지도를 다시 그립니다.
                        async let photoBooths = photoBoothClient.fetchSearchPhotoBooths(candidate, userCoordinate)
                        async let brandFilters = photoBoothClient.fetchSearchBrandFilters(candidate)
                        let result = try await PhotoBoothSearchResult(
                            photoBooths: photoBooths,
                            brandFilters: brandFilters
                        )
                        await send(.searchResultResponse(
                            .success(result),
                            candidate: candidate,
                            generation: generation
                        ))
                    } catch is CancellationError { return } catch {
                        await send(.searchResultResponse(
                            .failure(error),
                            candidate: candidate,
                            generation: generation
                        ))
                    }
                }
                .cancellable(id: CancelID.searchResult, cancelInFlight: true)

            case let .searchResultResponse(.success(result), candidate, generation):
                guard state.mode == .searching, state.requestGeneration == generation else { return .none }
                state.isFetchingSearchResult = false
                return .send(.delegate(.didSelectSearchResult(candidate: candidate, result: result)))

            case let .searchResultResponse(.failure(error), _, generation):
                guard state.mode == .searching, state.requestGeneration == generation else { return .none }
                state.isFetchingSearchResult = false
                // 이미 쌓아 둔 후보 목록을 덮지 않도록 실패는 알림으로만 알립니다.
                // TODO: 실패한 후보를 그 자리에서 다시 고르는 인라인 재시도가 필요한지 확인 필요.
                state.toast = NekiToastItem(PhotoBoothSearchFailure(error).message, style: .error)
                return .none

            case let .setUserCoordinate(coordinate):
                // 거리 표기의 기준은 검색을 시작할 때 고정하므로 여기서는 최신 위치만 받아 둡니다.
                guard state.userCoordinate != coordinate else { return .none }
                state.userCoordinate = coordinate
                return .none

            case .dismissSearch:
                // 검색어까지 비워 다음 진입이 처음 상태에서 시작하도록 합니다.
                state.searchText = ""
                state.resetSearch()
                return .merge(
                    .cancel(id: CancelID.candidatePage),
                    .cancel(id: CancelID.searchResult)
                )

            case .delegate:
                return .none
            }
        }
    }
}


// MARK: - PhotoBoothSearchFeature.State + Transition

private extension PhotoBoothSearchFeature.State {
    mutating func beginSearch(query: PhotoBoothSearchQuery) {
        requestGeneration &+= 1
        mode = .searching
        self.query = query
        // 이 검색이 끝날 때까지 거리 표기의 기준으로 쓸 좌표를 여기서 고정합니다.
        distanceOrigin = userCoordinate
        region = .init()
        station = .init()
        photoBooth = .init()
        rows = []
        isFetching = false
        isFetchingSearchResult = false
        failure = nil
        // 새 검색을 시작하면 직전 검색에서 남은 실패 알림은 더 이상 볼 이유가 없습니다.
        toast = nil
    }

    /// 받은 페이지를 가까운 순으로 세워 목록 끝에 이어붙이고, 새로 담은 후보가 있는지 알려 줍니다.
    ///
    /// 후보 검색 API는 기준 위치를 받지 않아 서버가 거리순으로 내려주지 않으므로 클라이언트가 세웁니다.
    /// 이미 보여준 후보 사이로 끼어들면 스크롤이 밀리므로 새로 받은 페이지 안에서만 세웁니다.
    mutating func append(_ page: PhotoBoothSearchCandidatePage) -> Bool {
        let pageCandidates = Self.nearestFirst(page.candidates, from: userLocation)
        let hasNewCandidates: Bool
        switch page.type {
        case .region: hasNewCandidates = region.append(pageCandidates, hasNext: page.hasNext)
        case .subwayStation: hasNewCandidates = station.append(pageCandidates, hasNext: page.hasNext)
        case .photoBooth: hasNewCandidates = photoBooth.append(pageCandidates, hasNext: page.hasNext)
        }
        guard hasNewCandidates else { return false }
        rebuildRows()
        return true
    }

    /// 거리 계산의 기준이 되는 위치입니다. 검색을 시작한 시점에 고정한 좌표를 씁니다.
    var userLocation: CLLocation? {
        distanceOrigin.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// 한 페이지를 가까운 순으로 세운 후보입니다.
    ///
    /// 거리를 알 수 없는 후보(위치 미동의, 좌표가 없는 종류)는 서버가 내려준 순서를 그대로 지키고,
    /// 거리가 같으면 먼저 내려온 후보를 앞에 둡니다.
    static func nearestFirst(
        _ candidates: [PhotoBoothSearchCandidate],
        from userLocation: CLLocation?
    ) -> [PhotoBoothSearchCandidate] {
        let distances = candidates.map { distance(to: $0, from: userLocation) }
        guard distances.contains(where: { $0 != nil }) else { return candidates }
        return candidates.indices
            .sorted { lhs, rhs in
                switch (distances[lhs], distances[rhs]) {
                case let (lhsDistance?, rhsDistance?):
                    lhsDistance == rhsDistance ? lhs < rhs : lhsDistance < rhsDistance
                case (_?, nil): true
                case (nil, _?): false
                case (nil, nil): lhs < rhs
                }
            }
            .map { candidates[$0] }
    }

    /// 정책 순서로 후보를 이어붙이고 각 후보에 노출할 거리를 채웁니다.
    ///
    /// 노출 순서는 페이지를 받을 때 정해지므로 여기서는 거리만 다시 계산합니다.
    mutating func rebuildRows() {
        let userLocation = self.userLocation
        rows = PhotoBoothSearchCandidateType.displayOrdered
            .flatMap { pagination(for: $0).candidates }
            .map { .init(candidate: $0, distance: Self.distance(to: $0, from: userLocation)) }
    }

    /// 정책상 노출해야 하는 거리(m)입니다.
    ///
    /// 위치 권한에 동의하지 않았거나, 거리를 노출하지 않는 종류(지역)이거나,
    /// 후보에 기준 좌표가 없으면(지하철역) `nil`입니다.
    static func distance(to candidate: PhotoBoothSearchCandidate, from userLocation: CLLocation?) -> Int? {
        guard candidate.type.providesDistance,
              let userLocation,
              let coordinate = candidate.coordinate
        else { return nil }
        let candidateLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return Int(userLocation.distance(from: candidateLocation).rounded())
    }

    mutating func resetSearch() {
        requestGeneration &+= 1
        mode = .inactive
        query = nil
        distanceOrigin = nil
        region = .init()
        station = .init()
        photoBooth = .init()
        rows = []
        isFetching = false
        isFetchingSearchResult = false
        failure = nil
        toast = nil
    }
}


// MARK: - PhotoBoothSearchFailure + Message

private extension PhotoBoothSearchFailure {
    /// 실패를 알릴 때 사용자에게 보여 줄 문구입니다.
    var message: String {
        switch self {
        case .network: "네트워크 연결이 불안정해요. 잠시 후 다시 시도해주세요."
        case .unknown: "일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요."
        }
    }
}
