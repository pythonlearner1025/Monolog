//
//  FolderView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all recordings

import SwiftUI
import AVFoundation

/*
 let fileManager = FileManager.default
 let rawFolderURL = URL(fileURLWithPath: folderPath).appendingPathComponent("raw")
 let date = Date()
 let newFileURL = rawFolderURL.appendingPathComponent("Recording: \(date.toString(dateFormat: "dd-MM-YY 'at' HH:mm:ss")).m4a")
 */

//  totalTime: formatter.string(from: TimeInterval(audioPlayer.duration))!
//duration: audioPlayer.duration
//        self.currentTime = "00:00"
//         self.absProgress = 0.0



struct FolderView: View {
    @State private var keyboardResponder = KeyboardResponder()
    @State var selection: FolderPageEnum = .normal
    @State private var isShowingSettings = false
    @State private var isShowingPicker = false
    @State private var searchText = ""
    @State private var formHasAppeared = false
    @ObservedObject private var audioRecorder = AudioRecorderModel()
    var folder: RecordingFolder
    var rawFolderURL: URL
    @State var recordings: [Recording]
    
    init(folder: RecordingFolder) {
        self.folder = folder
        self.recordings = self.fetchAllRecording()
        self.rawFolderURL = URL(fileURLWithPath: folder.path).appendingPathComponent("raw")
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
                            Text("\(formatter.string(from: recordings.[idx].createdAt))").font(.caption).foregroundColor(Color(.gray))
                            
                        }.padding(.bottom, 10)
                        Spacer()
                        NavigationLink(value: idx){
                            
                        }
                    }
                    VStack (alignment: .leading) {
                        ForEach(recordings[idx].outputs.outputs) {output in
                            switch output.type {
                            case .Summary:
                                selection == .summary ? OutputPreview(output: output) : EmptyView()
                            case .Action:
                                selection == .action ? OutputPreview(output: output) : EmptyView()
                            case .Transcript:
                                selection == .normal ? OutputPreview(output: output) : EmptyView()
                            case .Title: EmptyView()
                            case .Custom: EmptyView()
                            }
                        }
                    }
                }
                .id(UUID())
                // TODO: use audioPlayer of each recording object
                AudioControlView(audioPlayer: AudioPlayerModel(recordings[idx].audioPath))
                Divider().padding(.vertical, 15)  // Add a divider here
            }
            .onDelete{indexSet in
                indexSet.sorted(by: >).forEach{ i in
                    // TODO: 1) stop playing audio 2) delete file 3) pop from recordings to update View
                    recordings[i].audioPlayer.stopPlaying()
                    recordings[i].isPlaying = false
                    deleteRecording(recordings[i].audioPath,recordings[i].filePath)
                }
                recordings.remove(atOffsets: indexSet)
            }
        }
        .listRowSeparator(.hidden)
        .navigationDestination(for: Int.self){ idx in
            RecordingView(recordings[idx])
        }
        .onAppear { formHasAppeared = true }
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
                    audioRecorder.saveImportedRecording($recordings, oldAudioURL: importedAudioURL, newAudioURL: newAudioURL)
                    importedAudioURL.stopAccessingSecurityScopedResource()
                }
            } catch {
                print("error reading file")
            }
        }

        if (folder.name != "Recently Deleted" && keyboardResponder.currentHeight == 0) {
            HStack {
                Spacer()
               CameraButtonView(action: { isRecording in
                   print(isRecording)
                   if isRecording == true {
                       audioRecorder.stopRecording(&recordings)
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

    private var filteredItems: [Recording] {
        print("filtered items")
        if searchText.isEmpty {
            return recordings
        }
        else{
            return recordings.filter {item in
                item.title.localizedCaseInsensitiveContains(searchText)
                // TODO: search through all output.content text
            }
        }
    }
    
    func fetchAllRecording() -> [Recording]{
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folder.path)
        let directoryContents = try! fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // match the encoding strategy
        var res: [Recording] = []
        for i in directoryContents {
            if (i.lastPathComponent == "raw") {
                continue
            }
            else {
                let jsonURL = folderURL.appendingPathComponent("\(i.lastPathComponent)")
                do {
                    let data = try Data(contentsOf: jsonURL)
                    let recording = try decoder.decode(Recording.self, from: data)
                    res.append(recording)
                } catch {
                    print("An error occurred while decoding the recording object: \(error)")
                }
            }
        }

        res.sort(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending})
        return res
    }
    
    private func deleteRecording(_ audioPath: String, _ filePath: String) {
        let oldAudioURL = URL(audioPath)
        let oldFileURL = URL(filePath)
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let recentlyDeletedFolder = applicationSupportDirectory.appendingPathComponent("Recently Deleted")
        // if curr folder == recently deleted, perma delete
        if (recentlyDeletedFolder.lastPathComponent == URL(filePath: folderPath).lastPathComponent) {
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
        let newAudioURL = recentlyDeletedFolder.appendingPathComponent("raw/\(oldAudioURL.lastPathComponent)")
        let newFileURL = recentlyDeletedFolder.appendingPathComponent(oldFileURL.lastPathComponent)
        do {
            try fileManager.moveItem(at: oldAudioURL, to: newAudioURL)
        } catch {
            print("can't move audio\(error)")
        }
                                                                    
        do {
            try fileManager.moveItem(at: oldFileURL, to: newFileURL)
        } catch {
            print("can't move meta\(error)")
        }
    }
}

struct OutputPreview: View {
    @State var output: Output
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
    var idx: Int
    var body: some View {
        HStack {
            Text(audioPlayer.currentTime)
                .font(.caption.monospacedDigit())
            Slider(value: audioPlayer.absProgress, in: 0...audioPlayer.audioPlayer.duration).accentColor(Color.primary)
            Text(audioPlayer.totalTime)
                .font(.caption.monospacedDigit())
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
