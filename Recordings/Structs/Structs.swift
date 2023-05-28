//
//  Structs.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//

import Foundation
/*
struct Recording: Encodable, Decodable {
    var fileURL: URL
    var createdAt: Date
    var isPlaying: Bool
    var title: String // title of the recording, generated asynchronously
    var outputs: [Output] // list of outputs, generated asynchronously
}
 */

struct Output: Encodable,Decodable, Identifiable {
    var id = UUID()
    var type: OutputType
    var content: String
}

enum OutputType: String, Encodable, Decodable, CaseIterable {
    case Title
    case Transcript
    case Summary
    case Action
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

enum StyleType: String, Encodable, Decodable, CaseIterable {
    case casual
    case professional
}

struct Settings: Encodable, Decodable {
    var outputs: [OutputType]
    var length: LengthType
    var format: FormatType
    var style: StyleType
}

struct Update {
    var type: OutputType
    var content: String
}

/*
 all user default values
 - default outputs: summary, actions
 - length: short, medium, long
 - format: bullet point, paragraph
 - style: casual, professional
 */
