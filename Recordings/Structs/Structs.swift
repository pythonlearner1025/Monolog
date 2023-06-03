//
//  Structs.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//

import Foundation
import UIKit
import SwiftUI


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
    var prompt: String
    var name: String
    
    static var defaultSettings: OutputSettings {
        return OutputSettings(length: .short, format: .bullet, tone: .casual, prompt: "", name: "Default")
    }
}

struct Update {
    var type: OutputType
    var content: String
    var settings: OutputSettings
}

/*
 all user default values
 - default outputs: summary, actions
 - length: short, medium, long
 - format: bullet point, paragraph
 - style: casual, professional
 */
