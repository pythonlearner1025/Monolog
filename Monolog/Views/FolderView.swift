//
//  FolderView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all recordings

import SwiftUI
import AVFoundation

let barSpacing: Int = 5
let barWidth: Int = 3

struct BarView: View {
    var value: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(gradient: Gradient(colors: [.red]),
                     startPoint: .top,
                     endPoint: .bottom))
                .frame(width: CGFloat(barWidth), height: value)

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
    @EnvironmentObject var folderNavigationModel: FolderNavigationModel
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
   
    private func normalizeSoundLevel(levels: [Float], idx: Int) -> CGFloat {
        var level1 =  max(1, levels[idx] + 50)
        if levels[idx] == 0 || level1 <= 1 {
            level1 = 1
        }
        return CGFloat(level1)
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
                        NavigationLink(value: filteredItems[idx]){}.frame(width: 0)
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
                    if !audioRecorder.isRecording {
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
            }
            .onDelete{indexSet in}
            .listRowSeparator(.hidden)
            .deleteDisabled(audioRecorder.isRecording)
            .disabled(audioRecorder.isRecording)
        }
        .scrollDisabled(audioRecorder.isRecording)
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
        .navigationBarBackButtonHidden(audioRecorder.isRecording)
        .navigationBarItems(trailing: HStack{
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
                 primaryButton: .destructive(Text("Move")) {
                    recordingToMove = filteredItems[idxToMove]
                     showMoveLoadingAlert = false
                 },
                secondaryButton: .default(Text("Cancel").bold(), action: {
                    showMoveLoadingAlert=false
                }))
            } else {
                 return Alert(title: Text("Warning"),
                 message: Text("Are you sure you want to delete the recording while text is still loading? You will lose the loading text."),
                 primaryButton: .destructive(Text("Delete")) {
                    audioRecorder.cancelSave()
                    filteredItems[idxToDelete].audioPlayer.stopPlaying()
                    filteredItems[idxToDelete].audioPlayer.isPlaying = false
                    deleteRecording(filteredItems[idxToDelete].copy(), filteredItems[idxToDelete].audioPath, filteredItems[idxToDelete].filePath)
                    removeRecording(idx: idxToDelete)
                    showDeleteLoadingAlert=false
                 },
                secondaryButton: .default(Text("Cancel").bold(), action: {
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
                            HStack(spacing: CGFloat(barSpacing)) {
                                ForEach(audioRecorder.soundSamples.indices, id: \.self) { idx in
                                    BarView(value: normalizeSoundLevel(levels: audioRecorder.soundSamples, idx: idx))
                                }
                            }.frame(height: 70)
                        }
                        
                    }
                }
                
                HStack {
                    Spacer()
                    CameraButtonView(action: { recording in
                        if audioRecorder.isRecording {
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
                    .environmentObject(audioRecorder)
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
        // sort in descending order, oldest first
        let sortedFolderContents = directoryContents.sorted {
            let date1 = (try? fileManager.attributesOfItem(atPath: $0.path)[FileAttributeKey.creationDate] as? Date) ?? Date.distantPast
            let date2 = (try? fileManager.attributesOfItem(atPath: $1.path)[FileAttributeKey.creationDate] as? Date) ?? Date.distantPast
            return date1 > date2
        }
        for i in sortedFolderContents {
            if (i.lastPathComponent != "raw") {
                do {
                    let data = try Data(contentsOf: i)
                    let recording = try decoder.decode(Recording.self, from: data)
                    recording.folderPath = folder.path
                    recording.audioPlayer.reinit(folderPath: recording.folderPath, audioPath:  recording.audioPath)
                    recordings.recordings.append(recording)
                } catch {
                    print("An error occurred while decoding the recording object: \(error)")
                }
            }
        }
        recordingsModel[folder.path] = recordings
    }
    
    private func ensureDirectoryExists(at url: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
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
            try ensureDirectoryExists(at: recentlyDeletedRawFolder)
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
    
    private let recordingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [ .pad ]
        return formatter
    }()
    
    private let formatter: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "EEEE, MMMM d, yyyy"
         return formatter
     }()
}

