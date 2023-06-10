//
//  RecordingView.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//
import SwiftUI
import Foundation
import UIKit

struct RecordingView: View {
    @ObservedObject var outputs: Outputs
    @ObservedObject var recording: Recording
    var idx: Int
    @State private var isShowingSettings = false
    @State private var isShowingCustomOutput = false
    @State private var activeSheet: ActiveSheet?
    @State private var selectedLength = ""
    @State private var selectedTone = ""
    @State private var selectedFormat = ""
    @State private var customInput = ""
    @State private var showDelete: Bool = false
    @ObservedObject private var keyboardResponder = KeyboardResponder()
    
    init(recordings: Binding<[Recording]>, idx: Int){
        self.idx = idx
        self.recording = recordings.wrappedValue[idx]
        self.outputs = recordings.wrappedValue[idx].outputs
    }
    
    var body: some View {
        List{
            if outputs.outputs.first(where: {$0.type == .Title}) != nil {
                TitleView(output: recording.outputs.outputs.first(where: {$0.type == .Title})!, recording: recording)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))
            }
            ForEach(sortOutputs(outputs.outputs).filter { $0.type != .Title}) { output in
                HStack{
                    Group{
                        if output.type != .Transcript && showDelete {
                            VStack{
                                Button(action: {
                                    deleteOutput(output)
                                }) {
                                    ZStack{
                                        Image(systemName:"minus.circle")
                                            .font(.system(size: 25))
                                            .foregroundColor(.white)
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 25))
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.top, 10)
                                Spacer()
                            }
                        }
                    }
                    OutputView(output, recording: recording)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.systemBackground))
            }
        }
            .navigationBarItems(trailing:
            HStack{
                Menu {
                    Button(action: exportTranscript) {
                        Label("Export Transcript", systemImage: "doc.text")
                    }
                    Button(action: exportAudio) {
                        Label("Export Audio", systemImage: "waveform")
                    }
                }
            label: {
                Image(systemName: "square.and.arrow.up")
            }
                Button(action: {
                    isShowingCustomOutput.toggle()
                }) {
                    Image(systemName: "sparkles")
                }
                Button(action: {
                    showDelete.toggle()
                }){
                    Text("Edit")
                }
                if keyboardResponder.currentHeight != 0 {
                    Button(action: hideKeyboard) {
                        Text("Done")
                    }
                }
            })
            .listStyle(.plain)
            .sheet(isPresented: $isShowingCustomOutput){
                CustomOutputSheet(recording: recording)
            }
            .sheet(isPresented: $isShowingSettings) {
                if let outputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") {
                    SettingsView(selectedFormat: outputSettings.format, selectedLength: outputSettings.length, selectedTone: outputSettings.tone)
                }
            }
            .sheet(item: $activeSheet) {item in
                switch item {
                    case .exportText(let url):
                        ShareSheet(items: [url])
                    case .exportAudio(let url):
                        ShareSheet(items: [url])
                }
            }
            .onReceive(keyboardResponder.$currentHeight){ height in
                print(height)
            }
            .onReceive(outputs.$outputs){ outputs in
                print("-- onReceive new update --")
                print(outputs)
            }
    }
    
    func sortOutputs(_ outputs: [Output]) -> [Output] {
        print("recording update")
        return outputs.sorted { $0.type < $1.type }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // TODO: fix filePath is differen on each load - build folderPath again, from scratch.
    private func deleteOutput(_ output: Output){
        if let idxToDelete = outputs.outputs.firstIndex(where: {$0.id == output.id}) {
            outputs.outputs.remove(at: idxToDelete)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            do {
                let updatedData = try encoder.encode(recording)
                let folderURL = Util.buildFolderURL(recording.folderPath)
                let fileURL = folderURL.appendingPathComponent(recording.filePath)
                try updatedData.write(to: fileURL)
            } catch {
                print("error saving updated output \(error)")
            }
        }
    }
    
    private func exportTranscript() {
        let transcript = outputs.outputs.first { $0.type == .Transcript }?.content ?? ""
        let filename = "\(recording.title).txt"
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileURL = tempDirectoryURL.appendingPathComponent(filename)
        do {
            try transcript.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to create file")
            print("\(error)")
        }
        activeSheet = .exportText(fileURL)
    }
    
    private func exportAudio(){
        let originalURL = URL(fileURLWithPath: recording.audioPath)
        let filename = "\(recording.title).m4a"
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let newURL = tempDirectoryURL.appendingPathComponent(filename)
        
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: originalURL.path) {
                try fileManager.copyItem(at: originalURL, to: newURL)
            }
        } catch {
            print("Failed to rename file")
            print("\(error)")
        }
        activeSheet = .exportAudio(newURL)
    }
     
}

// TODO: add Recording
struct OutputView: View {
    @ObservedObject var output: Output
    @State private var isMinimized: Bool = false // Add this state variable
    @ObservedObject var cache = OutputCache<String, Bool>()
    let audioAPI: AudioRecorderModel = AudioRecorderModel()
    let recording: Recording
    
    init(_ output: Output, recording: Recording) {
       print("== On OutputView Init ==")
       self.output = output
       self.recording = recording
       let key = "\(output.id)"
       if let cachedValue = cache.value(forKey: key) {
           self.isMinimized = cachedValue
       } else {
           cache.insert(false, forKey: key)
           self.isMinimized = false
       }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: isMinimized ? "chevron.forward" : "chevron.down")
                Text(output.type != .Custom ? output.type.rawValue : getCustomOutputName(output))
                    .font(.headline)
                    .padding(.vertical)
                    .padding(.top, 5)
            }
            .padding(.vertical)
            .frame(height: 40)
            .onTapGesture {
                self.isMinimized.toggle()
                let key = "\(output.id)"
                cache.insert(isMinimized, forKey: key)
            }
            if output.error {
                Group {
                   if !isMinimized {
                       HStack{
                           // TODO: show error sign
                           Image(systemName: "exclamationmark.arrow.circlepath")
                           ZStack {
                               Text(output.content)
                           }
                       }.onTapGesture{
                           print("on retry")
                           print(output.content)
                           audioAPI.regenerateOutput(recording: recording, output: output)
                       }
                       
                   }
                }.animation(.easeInOut.speed(1.4),  value: isMinimized)
            } else if output.loading {
                Group {
                   if !isMinimized {
                       HStack{
                           ProgressView().scaleEffect(0.8, anchor: .center).padding(.trailing, 5)
                           ZStack {
                               Text(output.content)
                                   .foregroundColor(.gray)
                           }
                       }
                   }
                }.animation(.easeInOut.speed(1.4),  value: isMinimized)
            } else {
                Group {
                   if !isMinimized {
                       ZStack {
                           TextEditor(text: $output.content)
                               .font(.body)
                           Text(output.content).opacity(0).padding(.all, 8)
                       }
                   }
                }
                .animation(.easeInOut.speed(1.4), value: isMinimized)
                .onChange(of: output.content, perform: { value in
                   saveRecording()
                })
            }
        }
    }
    
    private func getCustomOutputName(_ output: Output) -> String{
        let outputs = recording.outputs.outputs
        let dupes = outputs.filter{ $0.settings.name == output.settings.name}
        let pos = dupes.firstIndex(where: {$0.id.uuidString == output.id.uuidString})
        if pos == 0 {
            return output.settings.name
        } else {
            return "\(output.settings.name)(\(pos!.description))"
        }
    }
    
    private func saveRecording() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(recording)
            try data.write(to: Util.buildFolderURL(recording.filePath))
            print("saved changes to disk")
        } catch {
            print("An error occurred while saving the recording object: \(error)")
        }
    }
    
}

struct TitleView: View {
    @ObservedObject var output: Output
    let audioAPI: AudioRecorderModel = AudioRecorderModel()
    let recording: Recording
    
    var body: some View {
        if output.error {
            HStack{
                Image(systemName: "exclamationmark.arrow.circlepath")
                Text(output.content).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -30).foregroundColor(.gray)
            }
            .onTapGesture{
                audioAPI.regenerateOutput(recording:recording, output:output)
            }
        } else if output.loading {
            HStack{
                ProgressView().scaleEffect(0.8, anchor: .center).padding(.trailing, 5)
                Text(output.content).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -30)
            }
            .onAppear(perform: {
                print("title loading appear")
                print(output.loading)
            })
        } else {
            Text(output.content).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -30)
        }
    }
}

struct CustomOutputSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let audioAPI: AudioRecorderModel = AudioRecorderModel()
    @State private var customPrompt: String = ""
    @State private var customName: String = ""
    let recording: Recording

    var body: some View{
        NavigationStack {
            Form {
                Section(header: Text("Create a new transformation of your transcript").textCase(nil)){
                    
                }
                
                Section(header: Text("Transform Name")) {
                    TextEditor(text: $customName)
                }
                
                Section(header: Text("Transform Prompt")) {
                    TextEditor(text: $customPrompt)
                        .frame(height: 120)
                }
                
                Button("Generate") {
                    if let savedOutputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") {
                        let currentOutputSettings = OutputSettings(length: savedOutputSettings.length, format: savedOutputSettings.format, tone: savedOutputSettings.tone ,name: customName,  prompt: customPrompt)
                        audioAPI.generateCustomOutput(recording: recording, outputSettings: currentOutputSettings)
                        UserDefaults.standard.storeOutputSettings(currentOutputSettings, forKey: "Output Settings")
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        print("err")
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationBarTitle("Transform")
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


