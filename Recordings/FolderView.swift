//
//  FolderView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all recordings

import SwiftUI
import AVFoundation

struct FolderView: View {
    @State private var keyboardResponder = KeyboardResponder()
    @State var selection: FolderPageEnum = .normal
    @State private var isShowingSettings = false
    @State private var isShowingPicker = false
    @State private var searchText = ""
    @State private var formHasAppeared = false
    @EnvironmentObject var audioRecorder: AudioRecorderModel
    var folder: RecordingFolder
    var rawFolderURL: URL
    @State var recordings: [Recording] = []
    
    init(folder: RecordingFolder) {
        print("FolderView refreshed")
        self.folder = folder
        self.rawFolderURL = Util.buildFolderURL(folder.path).appendingPathComponent("raw")
   }
    
    var body: some View {
        List{
            VStack{
                Picker(selection: $selection, label: Text("")){
                    ForEach(FolderPageEnum.allCases, id: \.self){ option in
                        Text(option.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color(.systemBackground))
            ForEach(filteredItems.indices, id: \.self) { idx in
                VStack (alignment: .leading){
                    HStack{
                        VStack(alignment:.leading) {
                            Text("\(recordings[idx].title)").font(.headline)
                            Text("\(formatter.string(from: recordings[idx].createdAt))").font(.caption).foregroundColor(Color(.gray))
                            
                        }.padding(.bottom, 10)
                        Spacer()
                        NavigationLink(value: idx){
                        }
                    }
                    VStack (alignment: .leading) {
                        if selection == .normal{
                            ForEach(recordings[idx].outputs.outputs) {output in
                                switch output.type {
                                case .Summary: EmptyView()
                                case .Action: EmptyView()
                                case .Transcript: OutputPreview(output: output)
                                case .Title: EmptyView()
                                case .Custom: EmptyView()
                                }
                            }
                        }
                        if selection == .action {
                            ForEach(recordings[idx].outputs.outputs) {output in
                                switch output.type {
                                case .Summary: EmptyView()
                                case .Action: OutputPreview(output: output)
                                case .Transcript: EmptyView()
                                case .Title: EmptyView()
                                case .Custom: EmptyView()
                                }
                            }
                        }
                        if selection == .summary {
                            ForEach(recordings[idx].outputs.outputs) {output in
                                switch output.type {
                                case .Summary: OutputPreview(output: output)
                                case .Action: EmptyView()
                                case .Transcript: EmptyView()
                                case .Title: EmptyView()
                                case .Custom: EmptyView()
                                }
                            }
                        }
                    }
                    AudioControlView(folderPath: recordings[idx].folderPath, audioPath: recordings[idx].audioPath)
                    Divider().padding(.vertical, 15)  // Add a divider here
                }
            }
            .onDelete{indexSet in
                indexSet.sorted(by: >).forEach{ i in
                    recordings[i].audioPlayer!.stopPlaying()
                    recordings[i].audioPlayer!.isPlaying = false
                    deleteRecording(recordings[i], recordings[i].audioPath, recordings[i].filePath)
                    
                    recordings.remove(atOffsets: indexSet)
                }
            }
            .id(UUID())
            .listRowSeparator(.hidden)

        }
        .listRowSeparator(.hidden)
        .navigationDestination(for: Int.self){ [$recordings] idx in
            RecordingView(recordings:$recordings, idx: idx)
        }
        // not here
        .onAppear {
            fetchAllRecording()
            formHasAppeared = true
        }
        .if(formHasAppeared) { view in
            view.searchable(text: $searchText)
        }
        .sheet(isPresented: $isShowingSettings){
            if let outputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") {
                SettingsView(selectedFormat: outputSettings.format, selectedLength: outputSettings.length, selectedTone: outputSettings.tone)
            }
        }
        .navigationTitle("\(folder.name)")
        .navigationBarItems(trailing: HStack{
            // TODO: import audio
            Button(action: {
                isShowingPicker = true
            }) {
                Image(systemName: "square.and.arrow.down") // This is a system symbol for uploading.
            }
            Button(action: {isShowingSettings.toggle()}){
                Image(systemName: "gearshape")
            }
            EditButton()
        })
        .listStyle(.plain)
        .fileImporter(isPresented: $isShowingPicker, allowedContentTypes: [.audio]) {(res) in
            do {
                let importedAudioURL = try res.get()
                if importedAudioURL.startAccessingSecurityScopedResource() {
                    let newAudioURL = rawFolderURL.appendingPathComponent("Recording: \(Date().toString(dateFormat: "dd-MM-YY 'at' HH:mm:ss")).m4a")
                    audioRecorder.saveImportedRecording(&recordings, oldAudioURL: importedAudioURL, newAudioURL: newAudioURL, folderURL: Util.buildFolderURL(folder.path))
                    importedAudioURL.stopAccessingSecurityScopedResource()
                }
            } catch {
                print("error reading file")
            }
        }

        if (folder.name != "Recently Deleted") {
            HStack {
                Spacer()
               CameraButtonView(action: { isRecording in
                   if isRecording {
                       audioRecorder.stopRecording(&recordings, folderURL: Util.buildFolderURL(folder.path))
                   } else {
                       audioRecorder.startRecording(audioURL: rawFolderURL.appendingPathComponent("Recording: \(Date().toString(dateFormat: "dd-MM-YY 'at' HH:mm:ss")).m4a"))
                   }
               })
                Spacer()
           }
           .background(Color(.secondarySystemBackground)) // Background color of the toolbar
           .edgesIgnoringSafeArea(.bottom)
           .padding(.top, -10)
        }
    }
    
    private func getOutput(idx: Int, type: OutputType) -> Output {
        return recordings[idx].outputs.outputs.first(where: {$0.type == type})!
    }

    private var filteredItems: [Recording] {
        if searchText.isEmpty {
            print("recordings update")
            return recordings
        }
        else{
            print("searchtext update")
            return recordings.filter {item in
                item.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func fetchAllRecording(){
        recordings = []
        let fileManager = FileManager.default
        let folderURL = Util.buildFolderURL(folder.path)
        let directoryContents = try! fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // match the encoding strategy
        print("num items in dir \(directoryContents.count)")
        for i in directoryContents {
            if (i.lastPathComponent == "raw") {
                continue
            }
            else {
                do {
                    print("==== dcoding == ")
                    let data = try Data(contentsOf: i)
                    let recording = try decoder.decode(Recording.self, from: data)
                    recordings.append(recording)
                    print(recordings.count)
                } catch {
                    print("An error occurred while decoding the recording object: \(error)")
                }
            }
        }
        
        recordings.sort(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending})
        print("count of recordings after fetch:")
        print(recordings.count)
        print(recordings)
    }
    
    private func deleteRecording(_ recording: Recording, _ audioPath: String, _ filePath: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let oldAudioURL = rawFolderURL.appendingPathComponent(audioPath)
        let oldFileURL = Util.buildFolderURL(folder.path).appendingPathComponent(filePath)
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let recentlyDeletedFolder = applicationSupportDirectory.appendingPathComponent("Recently Deleted")
        // if curr folder == recently deleted, perma delete
        if (recentlyDeletedFolder.lastPathComponent == folder.path) {
            print("Deleting permanently")
            do {
                try fileManager.removeItem(at: oldAudioURL)
            } catch {
                print("can't delete audio \(error)")
            }
            
            do {
                try fileManager.removeItem(at: oldFileURL)
            } catch {
                print("can't delete meta \(error)")
            }
            return
        }
        // move to recently deleted
        recording.folderPath = "Recently Deleted"
        let newAudioURL = recentlyDeletedFolder.appendingPathComponent("raw/\(audioPath)")
        let newFileURL = recentlyDeletedFolder.appendingPathComponent(filePath)
        do {
            try fileManager.moveItem(at: oldAudioURL, to: newAudioURL)
        } catch {
            print("can't move audio\(error)")
        }
                                                                    
        do {
            let data = try encoder.encode(recording)
            try data.write(to: newFileURL)
            try fileManager.removeItem(at: oldFileURL)
        } catch {
            print("can't move meta\(error)")
        }
    }
    private let formatter: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "EEEE, MMMM d, yyyy"
         return formatter
     }()
}

struct OutputPreview: View {
    @ObservedObject var output: Output
    var body: some View {
        if output.error {
            HStack{
                // TODO: show error sign
                Image(systemName: "exclamationmark.arrow.circlepath")
                ZStack {
                    Text(output.content).foregroundColor(.gray)
                }
            }
        } else if output.loading && output.content == "Loading" {
            HStack{
                ProgressView().scaleEffect(0.8, anchor: .center).padding(.trailing, 5) // Scale effect to make spinner a bit larger
                ZStack {
                    Text(output.content)
                        .font(.body).foregroundColor(.gray)
                }
            }
        } else {
            Text(output.content).font(.body).lineLimit(4).truncationMode(.tail)
        }
    }
}

struct AudioControlView: View {
    @ObservedObject var audioPlayer: AudioPlayerModel
    
    init(folderPath: String, audioPath: String){
        print("-- ACV --")
        print(audioPath)
        self.audioPlayer = AudioPlayerModel(folderPath: folderPath, audioPath: audioPath)
    }
    
    var body: some View {
        HStack {
            Text(audioPlayer.currentTime)
                .font(.caption.monospacedDigit())
            Slider(value: $audioPlayer.absProgress, in: 0...audioPlayer.audioPlayer.duration).accentColor(Color.primary)
            // TODO: format duration
            //Text(formatter.string(from: TimeInterval(audioPlayer.audioPlayer!.duration)))
                //.font(.caption.monospacedDigit())
        }
        .padding()
        HStack{
            Spacer()
            Button(action: {
                if audioPlayer.isPlaying == true {
                    audioPlayer.stopPlaying()
                }else{
                    audioPlayer.startPlaying()
                }}) {
                    Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title)
                        .imageScale(.large)
                        .foregroundColor(.primary)
                }.buttonStyle(.borderless)
            Spacer()
        }
    }
    private let formatter: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "EEEE, MMMM d, yyyy"
         return formatter
     }()
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var selectedFormat: FormatType
    @State var selectedLength: LengthType
    @State var selectedTone: ToneType
    
    var body: some View {
        NavigationStack{
            Form {
                Section(header: Text("Length")) {
                    Picker("Select Length", selection: $selectedLength) {
                        ForEach(LengthType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Format")) {
                    Picker("Select Format", selection: $selectedFormat) {
                        ForEach(FormatType.allCases, id: \.self) { option in
                            if option.rawValue == "bullet" {
                                Text("bullet point")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Tone")) {
                    Picker("Select Tone", selection: $selectedTone) {
                        ForEach(ToneType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Button("Save") {
                    if let savedOutputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") {
                        let outputSettings = OutputSettings(length: selectedLength, format: selectedFormat, tone: selectedTone, name: savedOutputSettings.name, prompt: savedOutputSettings.prompt)
                        UserDefaults.standard.storeOutputSettings(outputSettings, forKey: "Output Settings")
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        print("err")
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationBarTitle("Text Style")
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
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
