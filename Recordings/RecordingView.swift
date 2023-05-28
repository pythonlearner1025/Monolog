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
    @State private var selectedLength = ""
    @State private var selectedTone = ""
    @State private var selectedFormat = ""
    @State private var customInput = ""
    
    var index: Int

    var body: some View {
        NavigationStack{

            VStack{
                HStack{
                    List(vm.recordingsList[index].outputs) { output in
                        VStack(alignment: .leading){
                            switch output.type {
                            case .Summary: Text("Summary").font(.headline).padding(.vertical)
                            case .Action: Text("Actions").font(.headline).padding(.vertical)
                            case .Transcript: Text("Transcript").font(.headline).padding(.vertical)
                            case .Title: Text("THIS SHOULD NEVER BE SHOWN").font(.headline).padding(.vertical)
                            }
                            
                            Text(output.content).font(.body)
                            Divider()
                            
                        }.onAppear {
                            print("-- Added Output --")
                            print(output)
                        }.padding().listRowSeparator(.hidden)
                    }.scrollContentBackground(.hidden)
                    .onAppear {
                        print("-- Recording At RecordingView --")
                        print(vm.recordingsList[index])
                    }
                
                }
                    
                Image(systemName: "plus.circle")
                    .font(.system(size: 50, weight: .thin))
                    .onTapGesture {
                        showingSheet.toggle()
                    }.sheet(isPresented: $showingSheet){
                        SheetView(selectedLength: $selectedLength, selectedTone: $selectedTone, selectedFormat: $selectedFormat, customInput: $customInput)
                    }

                
            }.navigationTitle(vm.recordingsList[index].title)
            .onReceive(vm.$recordingsList) { updatedList in
                print("** LIST UPDATE IN RECORDING VIEW **.")
                print(vm.recordingsList[index].title)
                print(vm.recordingsList[index].outputs)
                print(vm.recordingsList[index].outputs)
            }.navigationBarItems(trailing: HStack{
                ShareLink(item: "Google.com"){
                    Image(systemName: "square.and.arrow.up")
                }
                Button(action: {}){
                    Image(systemName: "gearshape")
                }
            })
        }
    }
}

struct SheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedLength: String
    @Binding var selectedTone: String
    @Binding var selectedFormat: String
    @Binding var customInput: String
    
    let lengthOptions = ["Short", "Medium", "Long"]
    let toneOptions = ["Option 1", "Option 2", "Option 3", "Option 4", "Option 5"]
    let formatOptions = ["Option A", "Option B", "Option C", "Option D", "Option E"]
    
    var body: some View{
        NavigationStack {
                Form {
                    Section(header: Text("Length")) {
                        Picker("Select Length", selection: $selectedLength) {
                            ForEach(lengthOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Tone")) {
                        Picker("Select Tone", selection: $selectedTone) {
                            ForEach(toneOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(DefaultPickerStyle())
                    }
                    
                    Section(header: Text("Format")) {
                        Picker("Select Format", selection: $selectedFormat) {
                            ForEach(formatOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(DefaultPickerStyle())
                    }
                    
                    Section(header: Text("Custom Input")) {
                        TextEditor(text: $customInput)
                            .frame(height: 100)
                    }
                    
                    Button("Submit") {
                        // Perform submission logic here
                    }
                }
                .navigationBarTitle("Custom Output")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            
        }
    }
}


