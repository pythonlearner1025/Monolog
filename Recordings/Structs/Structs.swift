//
//  Structs.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//

import Foundation


class Folder: ObservableObject, Codable, Equatable, Hashable {
    @Published var name: String
    @Published var path: String
    @Published var count: Int
    
    enum CodingKeys: CodingKey {
        case name, path, count
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        count = try container.decode(Int.self, forKey: .count)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(count, forKey: .count)
    }
    
    init (name: String, path: String, count: Int) {
        self.name = name
        self.path = path
        self.count = count
    }
    
    static func == (lhs: Folder, rhs: Folder) -> Bool {
        return lhs.name == rhs.name
            && lhs.path == rhs.path
            && lhs.count == rhs.count
    }
    
    func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(path)
            hasher.combine(count)
    }
}

class ObservableRecording: ObservableObject, Codable, Equatable {
    @Published var filePath: String
    @Published var createdAt: Date
    @Published var isPlaying: Bool
    @Published var title: String
    @Published var outputs: [Output]
    @Published var progress: CGFloat = 0.0
    @Published var duration: Double = 0.0
    @Published var currentTime: String
    @Published var totalTime: String
    @Published var test = 0

    enum CodingKeys: CodingKey {
        case filePath, createdAt, isPlaying, title, outputs, currentTime, totalTime, progress, duration
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        filePath = try container.decode(String.self, forKey: .filePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPlaying = try container.decode(Bool.self, forKey: .isPlaying)
        title = try container.decode(String.self, forKey: .title)
        outputs = try container.decode([Output].self, forKey: .outputs)
        currentTime = try container.decode(String.self, forKey: .currentTime)
        totalTime = try container.decode(String.self, forKey: .totalTime)
        progress = try container.decode(CGFloat.self, forKey: .progress)
        duration = try container.decode(Double.self, forKey: .duration)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(filePath, forKey: .filePath)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isPlaying, forKey: .isPlaying)
        try container.encode(title, forKey: .title)
        try container.encode(outputs, forKey: .outputs)
        try container.encode(currentTime, forKey: .currentTime)
        try container.encode(totalTime, forKey: .totalTime)
        try container.encode(progress, forKey: .progress)
        try container.encode(duration, forKey: .duration)

    }

    // your initializer here
    init (filePath: String, createdAt: Date, isPlaying: Bool, title: String, outputs: [Output], totalTime: String, duration: Double){
        self.filePath = filePath
        self.createdAt = createdAt
        self.isPlaying = isPlaying
        self.title = title
        self.outputs = outputs
        self.currentTime = ""
        self.totalTime = totalTime
        self.duration = duration
    }
    
    static func == (lhs: ObservableRecording, rhs: ObservableRecording) -> Bool {
           return lhs.filePath == rhs.filePath
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
