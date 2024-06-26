//
//  Enums.swift
//  Recordings
//
//  Created by minjune Song on 6/3/23.
//

import Foundation
import SwiftUI

enum OutputType: String, Encodable, Decodable, CaseIterable, Comparable {
    case Title
    case Transcript
    case Summary
    case Custom
    
    static func < (lhs: OutputType, rhs: OutputType) -> Bool {
           switch (lhs, rhs) {
           case (.Title, _): return true
           case (_, .Title): return false
           case (.Summary, .Transcript): return true
           case (.Transcript, .Summary): return false
           case (.Custom, .Transcript): return true
           case (.Transcript, .Custom): return false
           default: return false
           }
       }
}

enum LengthType: String, Encodable, Decodable, CaseIterable {
    case short
    case medium
    case long
}

enum FormatType: String, Encodable, Decodable, CaseIterable {
    case bullet
    case paragraph
}

enum ToneType: String, Encodable, Decodable, CaseIterable {
    case casual
    case professional
}

enum ActiveSheet: Identifiable {
    case exportText(URL), exportAudio(URL)

    var id: Int {
        switch self {
        case .exportText: return 1
        case .exportAudio: return 2
        }
    }
}

enum OutputGenerationError: Error {
    case failure(error: Error, outputType: OutputType, transcript: String)
}

enum FolderPageEnum: String, CaseIterable {
    case normal = "Transcript"
    case summary = "Summary"
}

enum UpgradeContext: String, Codable, CaseIterable {
    case TranscriptUnlock
    case GenerationUnlock
}
