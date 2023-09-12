//
//  Structs.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//

import Foundation
import UIKit
import SwiftUI


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
    var transformType: TransformType?
    var language: String?
    
    static var defaultSettings: OutputSettings {
        return OutputSettings(length: .short, format: .bullet, tone: .casual, name: "Default", prompt: "")
    }
}

struct Update {
    var type: OutputType
    var content: String
    var settings: OutputSettings
}

