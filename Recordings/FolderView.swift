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
    @State private var showLoadingAlert = false
    @State private var isShowingSettings = false
    @State private var isShowingPicker = false
    @State private var isShowingMoveSheet = false
    @State private var recordingToMove: Recording?
    @State private var searchText = ""
    @State private var formHasAppeared = false
    @EnvironmentObject var audioRecorder: AudioRecorderModel
    var folder: RecordingFolder
    var rawFolderURL: URL
    @State var recordings: [Recording] = []
    
    init(folder: RecordingFolder) {
        print("INIT FOLDERVIEW")
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
                VStack (alignment: .leading) {
                    HStack{
                        VStack(alignment: .leading) {
                            ForEach(filteredItems[idx].outputs.outputs) {output in
                                switch output.type {
                                case .Summary: EmptyView()
                                case .Action: EmptyView()
                                case .Transcript: EmptyView()
                                case .Title: OutputPreview(output: output)
                                case .Custom: EmptyView()
                                }
                            }
                            Text("\(formatter.string(from: filteredItems[idx].createdAt))").font(.caption).foregroundColor(Color(.gray))
                        }.padding(.bottom, 10)
                        Spacer()
                        NavigationLink(value: idx){
                        }
                    }
                    if selection == .normal{
                        ForEach(filteredItems[idx].outputs.outputs) {output in
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
                        ForEach(filteredItems[idx].outputs.outputs) {output in
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
                        ForEach(filteredItems[idx].outputs.outputs) {output in
                            switch output.type {
                            case .Summary: OutputPreview(output: output)
                            case .Action: EmptyView()
                            case .Transcript: EmptyView()
                            case .Title: EmptyView()
                            case .Custom: EmptyView()
                            }
                        }
                    }
                    AudioControlView(folderPath: filteredItems[idx].folderPath, audioPath: filteredItems[idx].audioPath)
                    Divider().padding(.vertical, 15)  // Add a divider here
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        if outputsLoaded(filteredItems[idx]) {
                            audioRecorder.cancelSave()
                            filteredItems[idx].audioPlayer!.stopPlaying()
                            filteredItems[idx].audioPlayer!.isPlaying = false
                            deleteRecording(filteredItems[idx], filteredItems[idx].audioPath, filteredItems[idx].filePath)
                            removeRecording(idx: idx)
                        } else {
                            showLoadingAlert = true
                        }
                    } label: {
                        Label("Delete", systemImage: "minus.circle.fill")
                    }
                    Button {
                        if outputsLoaded(filteredItems[idx]) {
                            recordingToMove = filteredItems[idx]
                            isShowingMoveSheet = true
                        } else {
                            showLoadingAlert = true
                        }
                    } label: {
                        Label("Move", systemImage: "folder")
                    }
                    .tint(.green)
                }
            }
            .onDelete{indexSet in
            }
            .id(UUID())
            .listRowSeparator(.hidden)
        }
        .navigationDestination(for: Int.self){ [$recordings] idx in
            RecordingView(recordings:$recordings, idx: idx)
        }
        .onAppear {
            fetchAllRecording()
            formHasAppeared = true
            recordingToMove = nil
            print("fully fetched recordings:")
            print(recordings)
        }
        .if(formHasAppeared) { view in
            view.searchable(text: $searchText)
        }
        // TODO: bug
        .sheet(item: $recordingToMove) { recording in
            if let idx = recordings.firstIndex(where: {$0.id == recording.id}) {
                MoveSheet($recordings, idx: idx, currFolder: folder.path)
                    .onDisappear(perform: {
                        fetchAllRecording()
                        }
                    )
            } else {
                Text("Fok")
            }
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
        .alert(isPresented: $showLoadingAlert) {
            Alert(title: Text("Error Editing"), message: Text("Please wait until the recording has fully loaded"),
                  dismissButton: .default(Text("OK")) {
                showLoadingAlert=false
            }
                  )
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
    
    private func removeRecording(idx: Int) {
        let toDelete = filteredItems[idx]
        if let toDeleteIdx = recordings.firstIndex(of: toDelete) {
            recordings.remove(at: toDeleteIdx)
        }
    }
    
    private func getOutput(idx: Int, type: OutputType) -> Output {
        return recordings[idx].outputs.outputs.first(where: {$0.type == type})!
    }

    private var filteredItems: [Recording] {
        if searchText.isEmpty {
            return recordings
        }
        else{
            return recordings.filter {item in
                item.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func outputsLoaded(_ recording: Recording) -> Bool {
        for out in recording.outputs.outputs {
            if out.loading {
                return false
            }
        }
        return true
    }
    
    func fetchAllRecording(){
        recordings = []
        let fileManager = FileManager.default
        let folderURL = Util.buildFolderURL(folder.path)
        var directoryContents = try! fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        let decoder = Util.decoder()
        if (folder.path == "All") {
            let folderURLs = Util.allFolderURLs()
            for f in folderURLs {
                if (f.lastPathComponent != "Recently Deleted" && f.lastPathComponent != "All") {
                  let folderContents = try! fileManager.contentsOfDirectory(at: f, includingPropertiesForKeys: nil)
                directoryContents.append(contentsOf: folderContents)
                }
            }
        }
        for i in directoryContents {
            if (i.lastPathComponent != "raw") {
                do {
                    let data = try Data(contentsOf: i)
                    let recording = try decoder.decode(Recording.self, from: data)
                    recordings.append(recording)
                } catch {
                    print("An error occurred while decoding the recording object: \(error)")
                }
            }
        }
        recordings.sort(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending})
    }
    
    private func deleteRecording(_ recording: Recording, _ audioPath: String, _ filePath: String) {
        let fileManager = FileManager.default
        let encoder = Util.encoder()
        let rawFolderURL = Util.buildFolderURL(recording.folderPath).appendingPathComponent("raw")
        let oldAudioURL = rawFolderURL.appendingPathComponent(audioPath)
        let oldFileURL = Util.buildFolderURL(recording.folderPath).appendingPathComponent(filePath)
        let applicationSupportDirectory = Util.root()
        let recentlyDeletedFolder = applicationSupportDirectory.appendingPathComponent("Recently Deleted")
        // if curr folder == recently deleted, perma delete
        if (recentlyDeletedFolder.lastPathComponent == folder.path) {
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
        let recentlyDeletedRawFolder = recentlyDeletedFolder.appendingPathComponent("raw")
        let newAudioURL = recentlyDeletedRawFolder.appendingPathComponent(audioPath)
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
                    Text(output.content).foregroundColor(.gray).font(output.type == .Title ? .headline : .body)
                }
            }
        } else if output.loading && output.content == "Loading" {
            HStack{
                ProgressView().scaleEffect(0.8, anchor: .center).padding(.trailing, 5) // Scale effect to make spinner a bit larger
                ZStack {
                    Text(output.content)
                        .font(.body).foregroundColor(.gray).font(output.type == .Title ? .headline : .body)
                }
            }
        } else {
            Text(output.content).font(output.type == .Title ? .headline : .body).lineLimit(output.type == .Title ? nil : 4).truncationMode(.tail)
        }
    }
}

struct AudioControlView: View {
    @ObservedObject var audioPlayer: AudioPlayerModel
    
    init(folderPath: String, audioPath: String){
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
struct MoveSheet: View {
    @Binding var recordings: [Recording]
    let idx: Int
    let currFolder: String
    @Environment(\.presentationMode) private var presentationMode
    @State private var allFolders: [String] = []

    init(_ recordings: Binding<[Recording]>, idx: Int, currFolder: String){
        self._recordings = recordings
        self.idx = idx
        self.currFolder = currFolder
    }
    
    var body: some View {
        NavigationView{
            Form {
                Section(header: Text("Selected Recording")) {
                    Text(idx < recordings.count ? recordings[idx].title : "loading")
                }
                
                Section(header: Text("Folders")) {
                    ForEach(allFolders, id: \.self) { folder in
                        MoveFolderInnerView(name: folder)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                moveItem(folder)
                                presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .navigationBarTitle("Move Recording", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear(perform: {
            let allFolderURLs = Util.allFolderURLs()
            for url in allFolderURLs {
                if url.lastPathComponent != recordings[idx].folderPath && url.lastPathComponent != currFolder {
                    allFolders.append(url.lastPathComponent)
                }
            }
        })
    }
    

    private func moveItem(_ folder: String) {
        print("moving item")
        let fileManager = FileManager.default
        let recording = recordings[idx]
        let encoder = Util.encoder()
        let folderURL = Util.buildFolderURL(recording.folderPath)
        let rawFolderURL = folderURL.appendingPathComponent("raw")
        let oldAudioURL = rawFolderURL.appendingPathComponent(recording.audioPath)
        let oldFileURL = folderURL.appendingPathComponent(recording.filePath)
        recording.folderPath = folder
        let newFolderURL = Util.buildFolderURL(folder)
        let newRawFolderURL = newFolderURL.appendingPathComponent("raw")
        let newFileURL = newFolderURL.appendingPathComponent(recording.filePath)
        let newAudioURL = newRawFolderURL.appendingPathComponent(recording.audioPath)
        do {
            let data = try encoder.encode(recording)
            try data.write(to: newFileURL)
            try fileManager.removeItem(at: oldFileURL)
        } catch {
            print("can't move file \(error)")
        }
        
        do {
            try fileManager.moveItem(at: oldAudioURL, to: newAudioURL)
        } catch {
            print("can't move audio \(error)")
        }
        // After moving, dismiss the view
        recordings.remove(at: idx)
    }
}

struct MoveFolderInnerView: View {
    var name: String
    
    var body: some View {
        HStack{
            if name == "Recently Deleted" {
                Image(systemName: "trash")
            } else {
                Image(systemName: "folder")
            }
            Text(name)
            Spacer()
        }.font(.body)
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
