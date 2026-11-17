//
//  PoseEndpoint.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/30/26.
//

import Foundation

enum PoseEndpoint {
    case fetchPoseList(page: PageID?, size: Int?, peopleCount: String?, relation: String?, sortBy: String?)
    case fetchScrappedPoseList(page: PageID?, size: Int?, sortBy: String?)
    case fetchPoseDetail(poseID: PoseID)
    case fetchRandomPose(peopleCount: String, excludedPoseIDs: [PoseID])
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
        case let .fetchPoseList(page, size, peopleCount, relation, sortBy):
            var params: [String: String] = [:]
            if let page { params["page"] = String(page) }
            if let size { params["size"] = String(size) }
            if let peopleCount { params["headCount"] = peopleCount }
            if let relation { params["relation"] = relation }
            if let sortBy { params["sort"] = sortBy }
            return params
            
        case .fetchPoseDetail:
            return nil
            
        case let .fetchRandomPose(peopleCount, excludedPoseIDs):
            var params: [String: String] = ["headCount": peopleCount]
            // 서버는 쉼표로 이은 포즈 ID를 받아 그 포즈를 빼고 고릅니다. 뺄 포즈가 없으면 보내지 않습니다.
            if excludedPoseIDs.isEmpty == false { params["excludeIds"] = excludedPoseIDs.map(String.init).joined(separator: ",") }
            return params
            
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
