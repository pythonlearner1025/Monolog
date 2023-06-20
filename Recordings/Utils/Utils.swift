//
//  Util.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import Foundation
import UIKit
import SwiftUI

struct Util {
    static func buildFolderURL(_ folderLastPathComponent: String) -> URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return applicationSupportDirectory.appendingPathComponent(folderLastPathComponent)
    }
    
    static func allFolderURLs() -> [URL] {
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return [] }
        print("-- Util allFolderUrls --")
        print(applicationSupportDirectory)
        let folderURLs = try! fileManager.contentsOfDirectory(at: applicationSupportDirectory, includingPropertiesForKeys: nil)
        print("contents of folderURLS")
        print(folderURLs)
        return folderURLs
    }
    
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // match the encoding strategy
        return decoder
    }
    
    static func encoder() -> JSONEncoder {
         let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    static func root() -> URL {
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return  URL.applicationDirectory}
        return applicationSupportDirectory
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {}
}
