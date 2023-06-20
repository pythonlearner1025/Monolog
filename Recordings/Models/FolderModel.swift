//
//  FolderModel.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import Foundation

class Folder: ObservableObject, Codable, Equatable, Hashable, Identifiable {
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
    
    static func == (lhs: Folder, rhs: Folder) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(name)
            hasher.combine(path)
            hasher.combine(count)
    }
}
