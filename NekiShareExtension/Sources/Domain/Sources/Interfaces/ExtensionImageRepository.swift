//
//  ExtensionImageRepository.swift
//  NekiShareExtension
//
//  Created by SwainYun on 3/20/26.
//

import Foundation

enum ExtensionImageRepositoryError: Error {
    case directoryNotFound
    case cannotCreateDirectory
    case cannotWriteToDirectory
    case itemExistsAndRemoveFailed
}

protocol ExtensionImageRepository: Sendable {
    var sharedDirectory: URL? { get }
    
    func saveImage(from originalURL: URL, fileName: String) throws
}
