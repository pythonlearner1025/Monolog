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
    @State var selection: FolderPageEnum = .normal
    @State private var showLoadingAlert = false
    @State private var isShowingSettings = false
    @State private var isShowingPicker = false
    @State private var isShowingMoveSheet = false
    @State private var recordingToMove: Recording?
    @State private var searchText = ""
    @State private var formHasAppeared = false
    @State private var playingRecordingPath = ""
    @EnvironmentObject var audioRecorder: AudioRecorderModel
    @EnvironmentObject var recordingsModel: RecordingsModel
    @EnvironmentObject var useTranscriptModel: UseTranscriptModel
    var folder: Folder
    var rawFolderURL: URL
    
    init(folder: Folder) {
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
                    Divider().padding(.vertical, 15)  // Add a divider here
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        if outputsLoaded(filteredItems[idx]) {
                            audioRecorder.cancelSave()
                            filteredItems[idx].audioPlayer.stopPlaying()
                            filteredItems[idx].audioPlayer.isPlaying = false
                            deleteRecording(filteredItems[idx].copy(), filteredItems[idx].audioPath, filteredItems[idx].filePath)
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
            .onDelete{indexSet in}
            .listRowSeparator(.hidden)
        }
        .onAppear {
            fetchAllRecording()
            formHasAppeared = true
            recordingToMove = nil
        }
        .if(formHasAppeared) { view in
            view.searchable(text: $searchText)
        }
        .sheet(item: $recordingToMove) { recording in
            if let idx = filteredItems.firstIndex(where: {$0.id == recording.id}) {
                    MoveSheet($recordingsModel[folder.path].recordings, idx: idx, currFolder: folder.path)
                        .onDisappear(perform: {
                            fetchAllRecording()
                            }
                        )
            } else {
                Text("Error")
            }
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
                    if !useTranscriptModel.isEmpty() {
                        // transcript gen
                        audioRecorder.saveImportedRecording(&recordingsModel[folder.path].recordings, oldAudioURL: importedAudioURL, newAudioURL: newAudioURL, folderURL: Util.buildFolderURL(folder.path), generateText: true)
                        useTranscriptModel.useTranscript()
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
            Alert(title: Text("Error Editing"), message: Text("Please wait until the recording has fully loaded"),
                  dismissButton: .default(Text("OK")) {
                showLoadingAlert=false
            })
        }

        if (folder.name != "Recently Deleted") {
            HStack {
                Spacer()
               CameraButtonView(action: { isRecording in
                   if isRecording {
                       if !useTranscriptModel.isEmpty() {
                           // transcript gen
                           audioRecorder.stopRecording(&recordingsModel[folder.path].recordings, folderURL: Util.buildFolderURL(folder.path), generateText: true)
                           useTranscriptModel.useTranscript()
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
           .background(Color(.secondarySystemBackground))
           .edgesIgnoringSafeArea(.bottom)
           .padding(.top, -10)
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
        print("filtering")
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
            if out.loading {
                return false
            }
        }
        return true
    }
    
    private func fetchAllRecording(){
        if recordingsModel[folder.path].recordings.count > 0 {
            return
        }
       
        var recordings = Recordings()
        let fileManager = FileManager.default
        let decoder = Util.decoder()
        let folderURL = Util.buildFolderURL(folder.path)
        
        var directoryContents = try! fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
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
                    // fixing bug: when deleting folder, the folder attribute of recordings in it do not get updated
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
    }
    
    private let formatter: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "EEEE, MMMM d, yyyy"
         return formatter
     }()
}

