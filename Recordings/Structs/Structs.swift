//
//  Structs.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//

import Foundation

class ObservableRecording: ObservableObject, Codable, Equatable {
    @Published var fileURL: URL
    @Published var createdAt: Date
    @Published var isPlaying: Bool
    @Published var title: String
    @Published var outputs: [Output]
    @Published var currentTime: TimeInterval
    @Published var totalTime: TimeInterval

    enum CodingKeys: CodingKey {
        case fileURL, createdAt, isPlaying, title, outputs, currentTime, totalTime
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileURL = try container.decode(URL.self, forKey: .fileURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPlaying = try container.decode(Bool.self, forKey: .isPlaying)
        title = try container.decode(String.self, forKey: .title)
        outputs = try container.decode([Output].self, forKey: .outputs)
        currentTime = try container.decode(TimeInterval.self, forKey: .currentTime)
        totalTime = try container.decode(TimeInterval.self, forKey: .totalTime)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileURL, forKey: .fileURL)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isPlaying, forKey: .isPlaying)
        try container.encode(title, forKey: .title)
        try container.encode(outputs, forKey: .outputs)
        try container.encode(currentTime, forKey: .currentTime)
        try container.encode(totalTime, forKey: .totalTime)
    }

    // your initializer here
    init (fileURL: URL, createdAt: Date, isPlaying: Bool, title: String, outputs: [Output], totalTime: TimeInterval){
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.isPlaying = isPlaying
        self.title = title
        self.outputs = outputs
        self.currentTime = 0
        self.totalTime = totalTime
    }
    static func == (lhs: ObservableRecording, rhs: ObservableRecording) -> Bool {
           return lhs.fileURL == rhs.fileURL
               && lhs.createdAt == rhs.createdAt
               && lhs.isPlaying == rhs.isPlaying
               && lhs.title == rhs.title
               && lhs.outputs == rhs.outputs
               && lhs.currentTime == rhs.currentTime
               && lhs.totalTime == rhs.totalTime
       }
}

class Output: ObservableObject, Codable, Identifiable, Equatable {
    var id = UUID()
    var type: OutputType
    @Published var content: String
    
    init(type: OutputType, content: String) {
        self.type = type
        self.content = content
    }
    
    enum CodingKeys: CodingKey {
        case id, type, content
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(OutputType.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
    }
    
    static func == (lhs: Output, rhs: Output) -> Bool{
        return lhs.id == rhs.id
    }
}


enum OutputType: String, Encodable, Decodable, CaseIterable, Comparable {
    case Title
    case Transcript
    case Summary
    case Action
    
    static func < (lhs: OutputType, rhs: OutputType) -> Bool {
           switch (lhs, rhs) {
           case (.Title, _): return true
           case (_, .Title): return false
           case (.Summary, .Action), (.Summary, .Transcript): return true
           case (.Action, .Summary), (.Transcript, .Summary): return false
           case (.Action, .Transcript): return true
           case (.Transcript, .Action): return false
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
