//
//  PoseEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation

enum PoseEndpoint {
    case fetchPoseList(page: PageID?, size: Int?, peopleCount: String?, sortBy: String?)
    case fetchScrappedPoseList(page: PageID?, size: Int?, sortBy: String?)
    case fetchPoseDetail(poseID: PoseID)
    case fetchRandomPose(peopleCount: String)
    case scrapPose(poseID: PoseID, dto: ScrapPoseDTO.Request)
}


// MARK: - PoseEndpoint + Endpoint

extension PoseEndpoint: Endpoint {
    var authorizationType: AuthorizationType { .bearer }
    
    var contentType: HTTPContentType { .json }
    
    var path: String {
        switch self {
        case .fetchPoseList: return "/poses"
        case let .fetchPoseDetail(poseID): return "/poses/\(poseID)"
        case .fetchRandomPose: return "/poses/random"
        case let .scrapPose(poseID, _): return "/poses/\(poseID)/scrap"
        case .fetchScrappedPoseList: return "/poses/scrap"
        }
    }
    
    var queryParameters: [String : String]? {
        switch self {
        case let .fetchPoseList(page, size, peopleCount, sortBy):
            var params: [String: String] = [:]
            if let page { params["page"] = String(page) }
            if let size { params["size"] = String(size) }
            if let peopleCount { params["headCount"] = peopleCount }
            if let sortBy { params["sortOrder"] = sortBy }
            return params
            
        case .fetchPoseDetail:
            return nil
            
        case let .fetchRandomPose(peopleCount):
            return ["headCount": peopleCount]
            
        case .fetchScrappedPoseList(page: let page, size: let size, sortBy: let sortBy):
            var params: [String: String] = [:]
            if let page { params["page"] = String(page) }
            if let size { params["size"] = String(size) }
            if let sortBy { params["sortOrder"] = sortBy }
            return params
            
        case .scrapPose:
            return nil
        }
    }
    
    var method: HTTPMethodType {
        switch self {
        case .fetchPoseList, .fetchPoseDetail, .fetchRandomPose, .fetchScrappedPoseList: return .get
        case .scrapPose: return .patch
        }
    }
    
    var body: (any Encodable)? {
        switch self {
        case .fetchPoseList, .fetchPoseDetail, .fetchRandomPose, .fetchScrappedPoseList: return nil
        case let .scrapPose(_, dto): return dto
        }
    }
}
