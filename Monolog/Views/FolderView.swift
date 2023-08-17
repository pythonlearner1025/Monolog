//
//  FolderView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all recordings

import SwiftUI
import AVFoundation
let numberOfSamples: Int = 50

struct BarView: View {
    var value: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), // CHange color of bars here
                                     startPoint: .top,
                                     endPoint: .bottom))
                .frame(width: (UIScreen.main.bounds.width - CGFloat(numberOfSamples) * 6) / (CGFloat(numberOfSamples)), height: value)
        }
    }
}

struct FolderView: View {
    @State var selection: FolderPageEnum = .normal
    @State private var showMoveLoadingAlert = false
    @State private var showDeleteLoadingAlert = false
    @State private var showLoadingAlert = false
    @State private var idxToDelete = 0
    @State private var idxToMove = 0
    @State private var isShowingSettings = false
    @State private var isShowingPicker = false
    @State private var isShowingMoveSheet = false
    @State private var recordingToMove: Recording?
    @State private var searchText = ""
    @State private var formHasAppeared = false
    @State private var playingRecordingPath = ""
    @EnvironmentObject var audioRecorder: AudioRecorderModel
    @EnvironmentObject var recordingsModel: RecordingsModel
    @EnvironmentObject var consumableModel: ConsumableModel
    @EnvironmentObject var storeModel: StoreModel
    var folder: Folder
    var rawFolderURL: URL
    
    init(folder: Folder) {
        self.folder = folder
        self.rawFolderURL = Util.buildFolderURL(folder.path).appendingPathComponent("raw")
   }
    
    private func normalizeSoundLevel(level: Float) -> CGFloat {
        var level1 = max(3.0, CGFloat(level) + 50) / 2
        if level == 0{
            level1 = CGFloat(3.0)
        }
            
        return CGFloat(level1 * (50 / 25)) // scaled to max at 300 (our height of our bar)
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
                                case .Transcript: EmptyView()
                                case .Title: OutputPreview(output: output)
                                case .Custom: EmptyView()
                                }
                            }
                            Text("\(formatter.string(from: filteredItems[idx].createdAt))").font(.caption).foregroundColor(Color(.gray))
                        }.padding(.bottom, 10)
                        Spacer()
                        NavigationLink(value: filteredItems[idx]){
                        }
                    }
                    if selection == .normal{
                        ForEach(filteredItems[idx].outputs.outputs) {output in
                            switch output.type {
                            case .Summary: EmptyView()
                            case .Transcript: OutputPreview(output: output)
                            case .Title: EmptyView()
                            case .Custom: EmptyView()
                            }
                        }
                    }
                    if selection == .summary {
                        ForEach(filteredItems[idx].outputs.outputs) {output in
                            switch output.type {
                            case .Summary: OutputPreview(output: output)
                            case .Transcript: EmptyView()
                            case .Title: EmptyView()
                            case .Custom: EmptyView()
                            }
                        }
                    }
                    AudioControlView(filteredItems[idx].audioPlayer, playingRecordingPath: $playingRecordingPath)
                        .tag(idx)
                    Divider().padding(.vertical, 15)
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        if outputsLoaded(filteredItems[idx]) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
                                audioRecorder.cancelSave()
                                filteredItems[idx].audioPlayer.stopPlaying()
                                filteredItems[idx].audioPlayer.isPlaying = false
                                deleteRecording(filteredItems[idx].copy(), filteredItems[idx].audioPath, filteredItems[idx].filePath)
                                removeRecording(idx: idx)
                            }
                        } else {
                            idxToDelete = idx
                            showDeleteLoadingAlert = true
                            showLoadingAlert = true
                        }
                    } label: {
                        Label("Delete", systemImage: "minus.circle.fill")
                    }
                    Button{
                        if outputsLoaded(filteredItems[idx]) {
                            recordingToMove = filteredItems[idx]
                        } else {
                            idxToMove = idx
                            showMoveLoadingAlert = true
                            showLoadingAlert = true
                        }
                    } label: {
                        Label("Move to Folder", systemImage: "folder")
                    }
                    .tint(.green)
                    Button{
                        if storeModel.purchasedSubscriptions.count > 0 || !consumableModel.isTranscriptEmpty() {
                        audioRecorder.regenerateAll(recording: filteredItems[idx]){}
                        }
                    } label: {
                        Label("Redo Everything", systemImage: "goforward")
                    }
                    .tint(.blue)
                }
            }
            .onDelete{indexSet in}
            .listRowSeparator(.hidden)
        }
        .onAppear {
            if recordingsModel[folder.path].recordings.count == 0 {
                fetchAllRecording()
            }
            formHasAppeared = true
            recordingToMove = nil
        }
        .if(formHasAppeared) { view in
            view.searchable(text: $searchText)
        }
        .sheet(item: $recordingToMove) { recording in
            MoveSheet(recording: recording, currFolder: folder.path)
                .environmentObject(recordingsModel)
        }
        .sheet(isPresented: $isShowingSettings){
            if let outputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") {
                SettingsSheet(selectedFormat: outputSettings.format, selectedLength: outputSettings.length, selectedTone: outputSettings.tone)
            } else {
                Text("Error")
            }
        }
        .navigationTitle("\(folder.name)")
        .navigationBarItems(trailing: HStack{
            // TODO: import audio
            Button(action: {
                isShowingPicker = true
            }) {
                Image(systemName: "plus")
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
                    if !consumableModel.isTranscriptEmpty() || storeModel.purchasedSubscriptions.count > 0 {
                        // transcript gen
                        audioRecorder.saveImportedRecording(&recordingsModel[folder.path].recordings, oldAudioURL: importedAudioURL, newAudioURL: newAudioURL, folderURL: Util.buildFolderURL(folder.path), generateText: true)
                        consumableModel.useTranscript()
                    } else {
                        // no transcript gen
                        audioRecorder.saveImportedRecording(&recordingsModel[folder.path].recordings, oldAudioURL: importedAudioURL, newAudioURL: newAudioURL, folderURL: Util.buildFolderURL(folder.path), generateText: false)
                    }
                    importedAudioURL.stopAccessingSecurityScopedResource()
                }
            } catch {
                print("error reading file")
            }
        }
        .alert(isPresented: $showLoadingAlert) {
            if showMoveLoadingAlert {
                return Alert(title: Text("Warning"),
                 message: Text("Are you sure you want to move the recording while text is still loading? You will lose the loading text."),
                 primaryButton: .default(Text("Move")) {
                    recordingToMove = filteredItems[idxToMove]
                     showMoveLoadingAlert = false
                 },
                //TODO: why is Text(Don't move") not boldening?
                             secondaryButton: .default(Text("Don't Move").bold(), action: {
                    showMoveLoadingAlert=false
                }))
            } else {
                 return Alert(title: Text("Warning"),
                 message: Text("Are you sure you want to delete the recording while text is still loading? You will lose the loading text."),
                 primaryButton: .default(Text("Delete")) {
                    audioRecorder.cancelSave()
                    filteredItems[idxToDelete].audioPlayer.stopPlaying()
                    filteredItems[idxToDelete].audioPlayer.isPlaying = false
                    deleteRecording(filteredItems[idxToDelete].copy(), filteredItems[idxToDelete].audioPath, filteredItems[idxToDelete].filePath)
                    removeRecording(idx: idxToDelete)
                    showDeleteLoadingAlert=false
                 },
                              secondaryButton: .default(Text("Don't Delete").bold(), action: {
                    showDeleteLoadingAlert=false
             }))
            }
        }
        if (folder.name != "Recently Deleted") {
            VStack{
                if audioRecorder.isRecording{
                    VStack{
                        Text("Recording").padding(.top, 15).font(.headline)
                        Text(audioRecorder.currentTime).padding(.top, 0).font(.body).foregroundStyle(.gray)
                        VStack{
                            HStack(spacing: 6) {
                                ForEach(audioRecorder.soundSamples, id: \.self) { level in
                                    BarView(value: self.normalizeSoundLevel(level: level))
                                }
                            }.frame(height: 50)
                        }
                    }
                    
                }
                
                HStack {
                    Spacer()
                    CameraButtonView(action: { isRecording in
                        if isRecording {
                            if !consumableModel.isTranscriptEmpty() || storeModel.purchasedSubscriptions.count > 0 {
                                // transcript gen
                                audioRecorder.stopRecording(&recordingsModel[folder.path].recordings, folderURL: Util.buildFolderURL(folder.path), generateText: true)
                                consumableModel.useTranscript()
                            } else {
                                // no transcript gen
                                audioRecorder.stopRecording(&recordingsModel[folder.path].recordings, folderURL: Util.buildFolderURL(folder.path), generateText: false)
                            }
                        } else {
                            audioRecorder.startRecording(audioURL: rawFolderURL.appendingPathComponent("Recording: \(Date().toString(dateFormat: "dd-MM-YY 'at' HH:mm:ss")).m4a"))
                        }
                    })
                    Spacer()
                }
            }.background(Color(.secondarySystemBackground))
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    private func removeRecording(idx: Int) {
        let toDelete = filteredItems[idx]
        if let toDeleteIdx = recordingsModel[folder.path].recordings.firstIndex(of: toDelete) {
            recordingsModel[folder.path].recordings.remove(at: toDeleteIdx)
        }
    }
    
    private func getOutput(idx: Int, type: OutputType) -> Output {
        return recordingsModel[folder.path].recordings[idx].outputs.outputs.first(where: {$0.type == type})!
    }

    private var filteredItems: [Recording] {
        if searchText.isEmpty {
            return recordingsModel[folder.path].recordings
        }
        else{
            return recordingsModel[folder.path].recordings.filter {item in
                item.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func outputsLoaded(_ recording: Recording) -> Bool {
        if recording.folderPath == "Recently Deleted" {return true}
        for out in recording.outputs.outputs {
            if out.status == .loading {
                return false
            }
        }
        return true
    }
    
    private func fetchAllRecording(){
        let recordings = Recordings()
        let fileManager = FileManager.default
        let decoder = Util.decoder()
        let folderURL = Util.buildFolderURL(folder.path)
        let directoryContents = try! fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        for i in directoryContents {
            if (i.lastPathComponent != "raw") {
                do {
                    let data = try Data(contentsOf: i)
                    let recording = try decoder.decode(Recording.self, from: data)
                    if (folder.path == "Recently Deleted") {
                        recording.folderPath = "Recently Deleted"
                        recording.audioPlayer.reinit(folderPath: recording.folderPath, audioPath:  recording.audioPath)
                    }
                    recordings.recordings.append(recording)
                } catch {
                    print("An error occurred while decoding the recording object: \(error)")
                }
            }
        }
        recordings.recordings.sort(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending})
        recordingsModel[folder.path] = recordings
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
        // else, move to recently deleted
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
        recordingsModel["Recently Deleted"].recordings.insert(recording, at: 0)
    }
    
    private let formatter: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "EEEE, MMMM d, yyyy"
         return formatter
     }()
}

