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
    @State private var showingSheet = false
    var index: Int

    var body: some View {
        ZStack{
            LinearGradient(colors:[Color.black, Color.black], startPoint: .top, endPoint: .bottom).opacity(0.25).ignoresSafeArea()
            
            VStack{
                HStack{
                    Text(vm.recordingsList[index].title).font(.title).fontWeight(.bold)
                    Spacer()
                }.padding()
                Divider()
                List(vm.recordingsList[index].outputs) { output in
                    VStack(alignment: .leading){
                        switch output.type {
                        case .Summary: Text("Summary").font(.headline).padding(.vertical)
                        case .Action: Text("Actions").font(.headline).padding(.vertical)
                        case .Transcript: Text("Transcript").font(.headline).padding(.vertical)
                        case .Title: Text("THIS SHOULD NEVER BE SHOWN").font(.headline).padding(.vertical)
                        }
                        
                        Text(output.content).font(.body)
                        
                    }.onAppear {
                        print("-- Added Output --")
                        print(output)
                    }
                }
                .onAppear {
                    print("-- Recording At RecordingView --")
                    print(vm.recordingsList[index])
                }
                Image(systemName: "plus.circle")
                    .foregroundColor(.white)
                    .font(.system(size: 50))
                    .onTapGesture {
                        showingSheet.toggle()
                    }.sheet(isPresented: $showingSheet){
                        SheetView()
                    }

                
            }
            .onReceive(vm.$recordingsList) { updatedList in
                print("** LIST UPDATE IN RECORDING VIEW **.")
                print(vm.recordingsList[index].title)
                print(vm.recordingsList[index].outputs)
                print(vm.recordingsList[index].outputs)
            }
        }
    }
}

struct SheetView: View {
    
    var body: some View{
        Text("Hello")
    }
}


