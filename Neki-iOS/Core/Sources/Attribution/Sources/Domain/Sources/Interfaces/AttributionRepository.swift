//
//  AttributionRepository.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

public protocol AttributionRepository: Sendable {
    func initializeAttribution() async
    func trackCompleteRegistration() async
}
