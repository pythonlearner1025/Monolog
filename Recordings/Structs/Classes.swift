//
//  Classes.swift
//  Recordings
//
//  Created by minjune Song on 6/3/23.
//

import Foundation
import SwiftUI
import Combine
import UIKit

class FolderNavigationModel: ObservableObject {
    @Published var presentedItems = NavigationPath()
}

class KeyboardResponder: ObservableObject {
    @Published var currentHeight: CGFloat = 0

    var keyboardShow: AnyCancellable?
    var keyboardHide: AnyCancellable?

    init() {
        keyboardShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map {
                let height = ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
                print("Keyboard will show, height: \(height)")
                return height
            }
            .assign(to: \.currentHeight, on: self)
        
        keyboardHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in
                print("Keyboard will hide")
                return 0
            }
            .assign(to: \.currentHeight, on: self)
    }
}
class RecordingFolder: ObservableObject, Codable, Equatable, Hashable, Identifiable {
    @Published var id: UUID = UUID()
    @Published var name: String
    @Published var path: String
    @Published var count: Int
    
    enum CodingKeys: CodingKey {
        case name, path, count, id
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        count = try container.decode(Int.self, forKey: .count)
        id = try container.decode(UUID.self, forKey: .id)
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
    
    static func == (lhs: RecordingFolder, rhs: RecordingFolder) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(name)
            hasher.combine(path)
            hasher.combine(count)
    }
}


class Recording: ObservableObject, Codable, Equatable {
    @Published var audioPlayer: AudioPlayerModel?
    @Published var folderPath: String
    @Published var audioPath: String
    @Published var filePath: String
    @Published var createdAt: Date
    @Published var title: String
    @Published var outputs: Outputs


    enum CodingKeys: CodingKey {
        case filePath, createdAt, audioPath, title, outputs, folderPath
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        filePath = try container.decode(String.self, forKey: .filePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        outputs = try container.decode(Outputs.self, forKey: .outputs)
        audioPath = try container.decode(String.self, forKey: .audioPath)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        audioPlayer = AudioPlayerModel(folderPath: folderPath, audioPath: audioPath)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(filePath, forKey: .filePath)
        try container.encode(folderPath, forKey: .folderPath)
        try container.encode(title, forKey: .title)
        try container.encode(outputs, forKey: .outputs)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(title, forKey: .title)
        try container.encode(audioPath, forKey: .audioPath)
    }

    // your initializer here
    init (folderPath: String, audioPath: String, filePath: String, createdAt: Date, isPlaying: Bool, title: String, outputs: Outputs){
        self.audioPath = audioPath
        self.filePath = filePath
        self.createdAt = createdAt
        self.title = title
        self.outputs = outputs
        self.folderPath = folderPath
        self.audioPlayer = AudioPlayerModel(folderPath: folderPath, audioPath: audioPath)
    }
    
    static func == (lhs: Recording, rhs: Recording) -> Bool {
           return lhs.filePath == rhs.filePath
               && lhs.createdAt == rhs.createdAt
               && lhs.title == rhs.title
               && lhs.audioPath == rhs.audioPath
       }
}

class Recordings: ObservableObject {
    @Published var recordings = [Recording]()
}

class Outputs: ObservableObject, Codable {
    @Published var outputs = [Output]()
    
    enum CodingKeys: CodingKey {
           case outputs
   }
   
   init(outputs: [Output] = []) {
       self.outputs = outputs
   }

   required init(from decoder: Decoder) throws {
       let container = try decoder.container(keyedBy: CodingKeys.self)
       outputs = try container.decode([Output].self, forKey: .outputs)
   }
   
   func encode(to encoder: Encoder) throws {
       var container = encoder.container(keyedBy: CodingKeys.self)
       try container.encode(outputs, forKey: .outputs)
   }
}


class Output: ObservableObject, Codable, Identifiable, Equatable {
    var id = UUID()
    var type: OutputType
    @Published var content: String
    @Published var error: Bool = false
    @Published var loading: Bool = true
    @Published var settings: OutputSettings

    init(type: OutputType, content: String, settings: OutputSettings) {
        self.type = type
        self.content = content
        self.settings = settings
    }
    
    enum CodingKeys: CodingKey {
        case id, type, content, settings
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(OutputType.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        settings = try container.decodeIfPresent(OutputSettings.self, forKey: .settings) ?? OutputSettings.defaultSettings
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(settings, forKey: .settings)
    }
    
    static func == (lhs: Output, rhs: Output) -> Bool{
        return lhs.id == rhs.id
    }
}


class OutputCache<Key: Hashable, Value>: ObservableObject {
    private let wrappedCache = NSCache<WrappedKey, Entry>()

    func insert(_ value: Value, forKey key: Key) {
        let entry = Entry(value: value)
        wrappedCache.setObject(entry, forKey: WrappedKey(key))
    }

    func value(forKey key: Key) -> Value? {
        let entry = wrappedCache.object(forKey: WrappedKey(key))
        return entry?.value
    }

    private class WrappedKey: NSCopying {
        let key: Key

        init(_ key: Key) {
            self.key = key
        }

        func copy(with zone: NSZone? = nil) -> Any {
            return self
        }

        static func == (lhs: WrappedKey, rhs: WrappedKey) -> Bool {
            return lhs.key == rhs.key
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
    }

    private class Entry {
        let value: Value
        
        init(value: Value) {
            self.value = value
        }
    }
}
