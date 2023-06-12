//
//  Structs.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
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


struct Settings: Encodable, Decodable {
    var outputs: [OutputType]
    var length: LengthType
    var format: FormatType
    var tone: ToneType
}

struct OutputSettings: Encodable, Decodable {
    var length: LengthType
    var format: FormatType
    var tone: ToneType
    var name: String
    var prompt: String
    
    static var defaultSettings: OutputSettings {
        return OutputSettings(length: .short, format: .bullet, tone: .casual, name: "Default", prompt: "")
    }
}

struct Update {
    var type: OutputType
    var content: String
    var settings: OutputSettings
}

struct CustomOutputView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundColor(.blue)
        }
    }
}

struct CameraButtonView: View {

    @State var recording = false
    var action: ((_ recording: Bool) -> Void)?

    var body: some View {

        ZStack {
            Circle()
                .stroke(lineWidth: 4)
                .foregroundColor(.white)
                .frame(width: 63, height: 63)
            
            RoundedRectangle(cornerRadius: recording ? 8 : self.innerCircleWidth / 2)
                .foregroundColor(.red)
                .frame(width: self.innerCircleWidth, height: self.innerCircleWidth)

        }
        .animation(.linear(duration: 0.2))
        .padding(.top, 30)
        .padding(.bottom, 20)
        .onTapGesture {
            withAnimation {
                self.action?(self.recording)
                self.recording.toggle()
            }
        }

    }

    var innerCircleWidth: CGFloat {
        self.recording ? 32 : 55
    }
}
