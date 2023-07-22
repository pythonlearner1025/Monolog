//
//  SheetViews.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import SwiftUI
import StoreKit

struct SettingsSheet: View {
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
        NavigationStack{
            Form {
                Section(header: Text("Selected Recording")) {
                    Text(idx < recordings.count ? recordings[idx].title : "loading")
                }
                
                Section(header: Text("Folders")) {
                    ForEach(allFolders, id: \.self) { folder in
                        MoveFolderPreview(folder)
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

struct CustomOutputSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let audioAPI: AudioRecorderModel = AudioRecorderModel()
    @State private var customPrompt: String = ""
    @State private var customName: String = ""
    let recording: Recording
    @EnvironmentObject var consumableModel: ConsumableModel
    @EnvironmentObject var storeModel: StoreModel

    var body: some View{
        NavigationStack {
            Form {
                Section(header: Text("Text Name")) {
                    TextEditor(text: $customName)
                }
                
                Section(header: Text("Text Prompt")) {
                    TextEditor(text: $customPrompt)
                        .frame(height: 120)
                }
                Button("Generate") {
                    if !consumableModel.isOutputEmpty() || storeModel.subscriptions.count > 0 {
                        if let savedOutputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") {
                            let currentOutputSettings = OutputSettings(length: savedOutputSettings.length, format: savedOutputSettings.format, tone: savedOutputSettings.tone, name: customName,  prompt: customPrompt)
                            audioAPI.generateCustomOutput(recording: recording, outputSettings: currentOutputSettings)
                            UserDefaults.standard.storeOutputSettings(currentOutputSettings, forKey: "Output Settings")
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            print("err")
                            presentationMode.wrappedValue.dismiss()
                        }
                        consumableModel.useOutput()
                    }
                }
            }
            .navigationBarTitle("Generate Text")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let outputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings"){
                self.customPrompt = outputSettings.prompt
                self.customName = outputSettings.name
            }
        }
    }
}

// TODO: should be part of RecordingView. Using sheet to check functionality
struct RegenView: View {
    let audioAPI: AudioRecorderModel = AudioRecorderModel()
    let recording: Recording
    
    var body: some View {
        NavigationStack{
            Form{
                Button(action: {
                    audioAPI.regenerateAll(recording: recording)
                }) {
                    Text("Regenerate All")
                }
            }
            .navigationBarTitle("Error Transcribing", displayMode: .inline)
        }
    }
}

struct UpgradeSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let recording: Recording
    let context: UpgradeContext
    let audioAPI: AudioRecorderModel = AudioRecorderModel()
    @EnvironmentObject var storeModel: StoreModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Subscription Plans")) {
                    Picker("", selection: $storeModel.selectedProduct) {
                        ForEach(storeModel.subscriptions) { product in
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.description)
                            }.tag(product as Product?)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 100)
                }
                
                Section(header: Text("Enjoy unlimited transcriptions & Generations")) {
                    Button("Subscribe") {
                        Task {
                            if let selectedProduct = storeModel.selectedProduct {
                                await buy(product: selectedProduct)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Go UNLIMITED")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    func buy(product: Product) async {
        do {
            if try await storeModel.purchase(product) != nil {
                // regnerate all
                if context == .TranscriptUnlock {
                    recording.generateText = true
                    audioAPI.regenerateAll(recording: recording)
                }
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            print("purchase failed")
        }
    }
}
