//
//  RecordingView.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//
import SwiftUI
import Foundation

/*
 REMINDER: allow modification of settings inside the recordings view
    var settings = UserDefaults.standard.settings(forKey: "Settings") ?? Settings(outputs: [], length: .short, format: .bullet, style: .professional)
    settings.outputs.append(.TODO)
    UserDefaults.standard.store(settings, forKey: "Settings")
 */
/*
class ObservableRecording: ObservableObject {
    @Published var data: Recording

    init(recording: Recording) {
        self.data = recording
    }
}
*/

class ObservableRecording: ObservableObject, Codable {
    @Published var fileURL: URL
    @Published var createdAt: Date
    @Published var isPlaying: Bool
    @Published var title: String
    @Published var outputs: [Output]

    enum CodingKeys: CodingKey {
        case fileURL, createdAt, isPlaying, title, outputs
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileURL = try container.decode(URL.self, forKey: .fileURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPlaying = try container.decode(Bool.self, forKey: .isPlaying)
        title = try container.decode(String.self, forKey: .title)
        outputs = try container.decode([Output].self, forKey: .outputs)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileURL, forKey: .fileURL)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isPlaying, forKey: .isPlaying)
        try container.encode(title, forKey: .title)
        try container.encode(outputs, forKey: .outputs)
    }

    // your initializer here
    init (fileURL: URL, createdAt: Date, isPlaying: Bool, title: String, outputs: [Output]){
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.isPlaying = isPlaying
        self.title = title
        self.outputs = outputs
    }
}

struct RecordingView: View {
    @ObservedObject var vm: VoiceViewModel
    var index: Int

    var body: some View {
        VStack{
            Text(vm.recordingsList[index].title)
            List(vm.recordingsList[index].outputs) { output in
                VStack{
                    switch output.type {
                    case .Summary: Text("Summary")
                    case .Action: Text("Actions")
                    case .Transcript: Text("Transcript")
                    case .Title: Text("THIS SHOULD NEVER BE SHOWN")
                    }
                    Text(output.content)
                    
                }.onAppear {
                    print("-- Added Output --")
                    print(output)
                }
            }
            .onAppear {
                print("-- Recording At RecordingView --")
                print(vm.recordingsList[index])
            }
            
        }
        .onReceive(vm.$recordingsList) { updatedList in
            print("** LIST UPDATE IN RECORDING VIEW **.")
            print(vm.recordingsList[index].title)
            print(vm.recordingsList[index].outputs)
        }
    }
}
