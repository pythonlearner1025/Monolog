//
//  OutputModels.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import Foundation

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
    
    static var defaultOutputs: Outputs {
        return  Outputs(outputs: [Output(type: .Title, content: "Loading", settings: OutputSettings.defaultSettings), Output(type: .Transcript, content: "Loading", settings: OutputSettings.defaultSettings), Output(type: .Summary, content: "Loading", settings: OutputSettings.defaultSettings)])
    }
    subscript(idx: Int) -> Output {
        get {
            return outputs[idx]
        }
        set(newValue) {
            outputs[idx] = newValue
        }
    }
}

enum OutputStatus: String, Encodable, Decodable, CaseIterable {
    case restricted
    case completed
    case loading
    case error
}

class Output: ObservableObject, Codable, Identifiable, Equatable, CustomStringConvertible {
    var id = UUID()
    var type: OutputType
    @Published var content: String
    @Published var status: OutputStatus
    @Published var settings: OutputSettings
    

    init(type: OutputType, content: String, settings: OutputSettings) {
        self.type = type
        self.content = content
        self.settings = settings
        self.status = .loading
    }
    
    enum CodingKeys: CodingKey {
        case id, type, content, settings, status
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(OutputType.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        settings = try container.decodeIfPresent(OutputSettings.self, forKey: .settings) ?? OutputSettings.defaultSettings
        status = try container.decode(OutputStatus.self, forKey: .status)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(settings, forKey: .settings)
        try container.encode(status, forKey: .status)
    }
    
    static func == (lhs: Output, rhs: Output) -> Bool{
        return lhs.id == rhs.id
    }
    
    var description: String {
        return "Output(name: \(self.settings.name), content: \(self.content), type: \(self.type))"
    }
}

class OutputCache: ObservableObject {
    private let wrappedCache = NSCache<WrappedKey, Entry>()

    func insert(_ value: Bool, forKey key: String) {
        let entry = Entry(value: value)
        wrappedCache.setObject(entry, forKey: WrappedKey(key))
    }

    func value(forKey key: String) -> Bool {
        if let entry = wrappedCache.object(forKey: WrappedKey(key)) {
            return entry.value
        } else {
            return false
        }
    }

    private class WrappedKey: NSObject {
        let key: String

        init(_ key: String) {
            self.key = key
        }

        override var hash: Int {
            return key.hash
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let otherWrappedKey = object as? WrappedKey else {
                return false
            }
            
            return key == otherWrappedKey.key
        }
    }

    private class Entry {
        let value: Bool
        
        init(value: Bool) {
            self.value = value
        }
    }
}
