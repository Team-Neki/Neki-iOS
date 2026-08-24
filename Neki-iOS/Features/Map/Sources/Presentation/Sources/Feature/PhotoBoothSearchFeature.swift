//
//  PhotoBoothSearchFeature.swift
//  Neki-iOS
//
//  Created by SwainYun on 8/23/26.
//

import Foundation
import ComposableArchitecture

@Reducer
public struct PhotoBoothSearchFeature {
    struct PaginationState<Element: Equatable>: Equatable {
        var elements: [Element] = []
        var loadedPages: Set<Int> = []
        var hasNextPage: Bool = false
        var isFetching: Bool = false
        var didFail: Bool = false
    }

    @ObservableState
    public struct State: Equatable {
        public enum Mode: Equatable {
            case inactive
            case candidateSelection
            case searchResults
        }

        var mode: Mode = .inactive
        var query: PhotoBoothSearchQuery?
        var selectedCandidate: PhotoBoothSearchCandidate?
        var candidatePagination = PaginationState<PhotoBoothSearchCandidate>()
        var resultPagination = PaginationState<PhotoBooth>()
        var requestGeneration: Int = .zero

        public init() {}
    }

    public enum Action {
        case beginCandidateSelection(PhotoBoothSearchQuery)
        case fetchCandidatePage(Int)
        case candidatePageResponse(Result<PhotoBoothSearchCandidatePage, Error>, pageNumber: Int, generation: Int)
        case didSelectCandidate(PhotoBoothSearchCandidate)
        case fetchSearchResultPage(Int)
        case searchResultPageResponse(Result<PhotoBoothSearchResultPage, Error>, candidate: PhotoBoothSearchCandidate, pageNumber: Int, generation: Int)
        case endSearch
    }

    private enum CancelID: Hashable {
        case candidatePage
        case searchResultPage
    }

    @Dependency(\.photoBoothClient) private var photoBoothClient

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .beginCandidateSelection(query):
                state.prepareCandidateSelection(query: query)
                return .merge(
                    .cancel(id: CancelID.candidatePage),
                    .cancel(id: CancelID.searchResultPage)
                )

            case let .fetchCandidatePage(page):
                guard state.mode == .candidateSelection,
                      let query = state.query,
                      state.candidatePagination.canFetch(page: page)
                else { return .none }
                let generation = state.requestGeneration
                state.candidatePagination.beginFetching()
                return .run { send in
                    do {
                        let response = try await photoBoothClient.fetchSearchCandidates(query, page)
                        await send(.candidatePageResponse(
                            .success(response),
                            pageNumber: page,
                            generation: generation
                        ))
                    } catch is CancellationError { return } catch {
                        await send(.candidatePageResponse(
                            .failure(error),
                            pageNumber: page,
                            generation: generation
                        ))
                    }
                }
                .cancellable(id: CancelID.candidatePage)

            case let .candidatePageResponse(.success(page), pageNumber, generation):
                guard state.mode == .candidateSelection,
                      state.requestGeneration == generation
                else { return .none }
                guard page.candidates.allSatisfy({ $0.type == page.type }) else {
                    state.candidatePagination.failFetching()
                    return .none
                }
                state.candidatePagination.append(
                    contentsOf: page.candidates,
                    page: pageNumber,
                    hasNextPage: page.hasNext
                )
                return .none

            case let .candidatePageResponse(.failure, _, generation):
                guard state.mode == .candidateSelection,
                      state.requestGeneration == generation
                else { return .none }
                state.candidatePagination.failFetching()
                return .none

            case let .didSelectCandidate(candidate):
                guard state.mode == .candidateSelection,
                      state.candidatePagination.elements.contains(candidate)
                else { return .none }
                state.prepareSearchResults(candidate: candidate)
                return .merge(
                    .cancel(id: CancelID.candidatePage),
                    .cancel(id: CancelID.searchResultPage)
                )

            case let .fetchSearchResultPage(page):
                guard state.mode == .searchResults,
                      let candidate = state.selectedCandidate,
                      state.resultPagination.canFetch(page: page)
                else { return .none }
                let generation = state.requestGeneration
                state.resultPagination.beginFetching()
                return .run { send in
                    do {
                        let response = try await photoBoothClient.fetchSearchPhotoBooths(candidate, page)
                        await send(.searchResultPageResponse(
                            .success(response),
                            candidate: candidate,
                            pageNumber: page,
                            generation: generation
                        ))
                    } catch is CancellationError { return } catch {
                        await send(.searchResultPageResponse(
                            .failure(error),
                            candidate: candidate,
                            pageNumber: page,
                            generation: generation
                        ))
                    }
                }
                .cancellable(id: CancelID.searchResultPage)

            case let .searchResultPageResponse(.success(page), candidate, pageNumber, generation):
                guard state.mode == .searchResults,
                      state.requestGeneration == generation,
                      state.selectedCandidate == candidate
                else { return .none }
                state.resultPagination.append(
                    contentsOf: page.photoBooths,
                    page: pageNumber,
                    hasNextPage: page.hasNext
                )
                return .none

            case let .searchResultPageResponse(.failure, candidate, _, generation):
                guard state.mode == .searchResults,
                      state.requestGeneration == generation,
                      state.selectedCandidate == candidate
                else { return .none }
                state.resultPagination.failFetching()
                return .none

            case .endSearch:
                state.resetSearch()
                return .merge(
                    .cancel(id: CancelID.candidatePage),
                    .cancel(id: CancelID.searchResultPage)
                )
            }
        }
    }
}


// MARK: - PhotoBoothSearchFeature.State + Transition

private extension PhotoBoothSearchFeature.State {
    mutating func prepareCandidateSelection(query: PhotoBoothSearchQuery) {
        requestGeneration &+= 1
        mode = .candidateSelection
        self.query = query
        selectedCandidate = nil
        candidatePagination.reset()
        resultPagination.reset()
    }

    mutating func prepareSearchResults(candidate: PhotoBoothSearchCandidate) {
        requestGeneration &+= 1
        mode = .searchResults
        selectedCandidate = candidate
        candidatePagination.deactivate()
        resultPagination.reset()
    }

    mutating func resetSearch() {
        requestGeneration &+= 1
        mode = .inactive
        query = nil
        selectedCandidate = nil
        candidatePagination.reset()
        resultPagination.reset()
    }
}


// MARK: - PhotoBoothSearchFeature.PaginationState + Mutation

private extension PhotoBoothSearchFeature.PaginationState {
    func canFetch(page: Int) -> Bool {
        isFetching == false &&
        loadedPages.contains(page) == false &&
        (loadedPages.isEmpty || hasNextPage)
    }

    mutating func beginFetching() {
        isFetching = true
        didFail = false
    }

    mutating func append(contentsOf newElements: [Element], page: Int, hasNextPage: Bool) {
        elements.append(contentsOf: newElements)
        loadedPages.insert(page)
        self.hasNextPage = hasNextPage
        isFetching = false
        didFail = false
    }

    mutating func failFetching() {
        isFetching = false
        didFail = true
    }

    mutating func deactivate() {
        hasNextPage = false
        isFetching = false
        didFail = false
    }

    mutating func reset() {
        self = .init()
    }
}
