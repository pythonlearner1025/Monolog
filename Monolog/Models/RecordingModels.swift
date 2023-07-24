//
//  RecordingModels.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import Foundation
import SwiftUI
import Combine
import UIKit

class Recording: ObservableObject, Codable, Equatable, Identifiable, Hashable {
    @Published var audioPlayer: AudioPlayerModel
    @Published var folderPath: String
    @Published var audioPath: String
    @Published var filePath: String
    @Published var createdAt: Date
    @Published var title: String
    @Published var outputs: Outputs
    @Published var generateText: Bool
    var id: UUID = UUID()
    private var cancellables = Set<AnyCancellable>()

    enum CodingKeys: CodingKey {
        case filePath, createdAt, audioPath, title, outputs, folderPath, id, generateText
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        filePath = try container.decode(String.self, forKey: .filePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        outputs = try container.decode(Outputs.self, forKey: .outputs)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        audioPath = try container.decode(String.self, forKey: .audioPath)
        generateText = try container.decode(Bool.self, forKey: .generateText)
        id = try container.decode(UUID.self, forKey: .id)
        audioPlayer = AudioPlayerModel(folderPath: try container.decode(String.self, forKey: .folderPath), audioPath: try container.decode(String.self, forKey: .audioPath))
        //setupPublishers()
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
        try container.encode(id, forKey: .id)
        try container.encode(generateText, forKey: .generateText)
    }

    // your initializer here
    init (folderPath: String, audioPath: String, filePath: String, createdAt: Date, title: String, outputs: Outputs, generateText: Bool){
        self.audioPath = audioPath
        self.filePath = filePath
        self.createdAt = createdAt
        self.title = title
        self.outputs = outputs
        self.folderPath = folderPath
        self.audioPlayer = AudioPlayerModel(folderPath: folderPath, audioPath: audioPath)
        self.generateText = generateText
        //setupPublishers()
    }
    
    private func setupPublishers() {
       cancellables.removeAll()
       audioPlayer.objectWillChange
           .sink { [weak self] _ in
               self?.objectWillChange.send()
           }
           .store(in: &cancellables)
    }
    
    static func == (lhs: Recording, rhs: Recording) -> Bool {
        return lhs.id == rhs.id
    }
    
    func copy() -> Recording {
        return Recording(folderPath: folderPath, audioPath: audioPath, filePath: filePath, createdAt: createdAt, title: title, outputs: outputs, generateText: generateText)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}


class RecordingsModel: ObservableObject {
    var cancellables = Set<AnyCancellable>()
    @Published var folderRecordings: [String: Recordings] = [:] {
        didSet {
            cancellables.removeAll()
            for (_, recordings) in folderRecordings {
                recordings.objectWillChange
                    .sink { [weak self] _ in
                        self?.objectWillChange.send()
                    }
                    .store(in: &cancellables)
            }
        }
    }

    subscript(key: String) -> Recordings {
        get {
            if folderRecordings[key] != nil {
                return folderRecordings[key]!
            }
            return Recordings()
        }
        set(newValue) {
            folderRecordings[key] = newValue
        }
    }
}


class Recordings: ObservableObject {
    var cancellables = Set<AnyCancellable>()
    @Published var recordings = [Recording]() {
        didSet{
            cancellables.removeAll()
            for recording in recordings {
                recording.objectWillChange.sink{ [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
            }
        }
    }
    
    subscript(idx: Int) -> Recording {
        get {
            return recordings[idx]
        }
        set(newValue) {
            recordings[idx] = newValue
        }
    }
}
