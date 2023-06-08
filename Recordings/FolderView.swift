//
//  FolderView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all recordings

import SwiftUI
import AVFoundation

// TODO: create raw  folder

// send filePath to player:
/*
 let filePath = rawFolderURL.appendingPathComponent("Recording: \(Date().toString(dateFormat: "dd-MM-YY 'at' HH:mm:ss")).m4a")
 //print("Recording will be saved at: \(fileName)")
 */

struct FolderView: View {
    @ObservedObject private var keyboardResponder = KeyboardResponder()
    @State var selection: FolderPageEnum = .normal
    @State private var isShowingSettings = false
    @State private var isShowingPicker = false
    @State private var searchText = ""
    @State private var formHasAppeared = false
    private var audio: VoiceViewModel
    
    var folder: RecordingFolder
    @State var recordings: [ObservableRecording]
    init(folder: RecordingFolder) {
        self.folder = folder
        self.recordings = self.fetchAllRecording()
        self.audio = VoiceViewModel(folderPath: folder.path)
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
                            if selection == .normal{
                                ForEach(recordings.text.outputs) {output in
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
                                ForEach(recordings.text.outputs) {output in
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
                                ForEach(recordings.text.outputs) {output in
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
                        
                    }
                    .id(UUID())
                    HStack {
                        Text(recordings.currentTime)
                            .font(.caption.monospacedDigit())
                        Slider(value: recordings.absProgress, in: 0...recordings[idx].duration).accentColor(Color.primary)
                        Text(recordings[idx].totalTime)
                            .font(.caption.monospacedDigit())
                    }
                    .padding()
                    AudioControlView(vm: vm, idx: idx)
                    Divider().padding(.vertical, 15)  // Add a divider here
                }
                .onDelete{indexSet in
                    indexSet.sorted(by: >).forEach{ i in
                        audio.deleteRecording()
                        audio.stopPlaying()
                        recordings[i].isPlaying = false
                        deleteRecording(audioPath: recordings[i].filePath)
                    }
                    recordings.remove(atOffsets: indexSet)
                }
                .listRowSeparator(.hidden)
            }
            .navigationDestination(for: Int.self){ idx in
                RecordingView(vm: vm, os: recordings.outputs, index: idx, recordingURL: getRecordingURL(filePath: recordings.filePath))
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
                    let fileURL = try res.get()
                    if fileURL.startAccessingSecurityScopedResource() {
                        audio.saveImportedRecording($recordings, filePath: fileURL)
                        fileURL.stopAccessingSecurityScopedResource()
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
                           audio.stopRecording(&recordings)
                       } else {
                           audio.startRecording()
                       }
                   })
                    Spacer()
               }
               .background(Color(.secondarySystemBackground)) // Background color of the toolbar
               .edgesIgnoringSafeArea(.bottom)
               .padding(.top, -10)
            }
    }

    func getRecordingURL(filePath: String) -> URL {
        let folderURL = URL(fileURLWithPath: folder.path)
        return folderURL.appendingPathComponent("\(filePath).json")
    }
    
    private let formatter: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "EEEE, MMMM d, yyyy"
         return formatter
     }()
    
    private var filteredItems: [ObservableRecording] {
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
    
    func fetchAllRecording() -> [ObservableRecording]{
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folder.path)
        let directoryContents = try! fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // match the encoding strategy
        var res: [ObservableRecording] = []
        for i in directoryContents {
            if (i.lastPathComponent == "raw") {
                continue
            }
            else {
                let jsonURL = folderURL.appendingPathComponent("\(i.lastPathComponent)")
                do {
                    let data = try Data(contentsOf: jsonURL)
                    let recording = try decoder.decode(ObservableRecording.self, from: data)
                    res.append(recording)
                } catch {
                    print("An error occurred while decoding the recording object: \(error)")
                }
            }
        }

        res.sort(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending})
        return res
    }
    
    private func deleteRecording(audioPath: String) {
        let oldAudioURL = getAudioURL(filePath: audioPath)
        let oldMetaURL = getRecordingMetaURL(filePath: audioPath)
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
                try fileManager.removeItem(at: oldMetaURL)
            } catch {
                print("can't delete meta \(error)")
            }
            return
        }
        // move to recently deleted
        let newAudioURL = recentlyDeletedFolder.appendingPathComponent("raw/\(URL(filePath: audioPath).lastPathComponent)")
        let newMetaURL = recentlyDeletedFolder.appendingPathComponent(oldMetaURL.lastPathComponent)
        
        do {
            try fileManager.moveItem(at: oldAudioURL, to: newAudioURL)
        } catch {
            print("can't move audio\(error)")
        }
                                                                    
        do {
            try fileManager.moveItem(at: oldMetaURL, to: newMetaURL)
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
    @ObservedObject var vm: VoiceViewModel
    var idx: Int
    
    var body: some View {
        HStack{
            Spacer()
            Button(action: {
                if vm.recordingsList[idx].isPlaying == true {
                    vm.stopPlaying(index: idx)
                }else{
                    vm.startPlaying(index: idx, filePath: vm.recordingsList[idx].filePath)
                }}) {
                    Image(systemName: vm.recordingsList[idx].isPlaying ? "stop.fill" : "play.fill")
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
