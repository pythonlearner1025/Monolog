//
//  RecordingView.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//
import SwiftUI
import Foundation

struct RecordingView: View {
    @ObservedObject var vm: VoiceViewModel
    @State private var isShowingSettings = false
    @State private var isShowingCustomOutput = false
    @State private var activeSheet: ActiveSheet?
    @State private var selectedLength = ""
    @State private var selectedTone = ""
    @State private var selectedFormat = ""
    @State private var customInput = ""
    
    var index: Int
    var recordingURL: URL
    var body: some View {
        NavigationStack{
            List{
                if !vm.recordingsList[index].outputs.contains(where: {$0.type == .Title}) {
                    Text(vm.recordingsList[index].title).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -30)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color(.systemBackground))
                } else {
                    if let title = vm.recordingsList[index].outputs.first(where: {$0.type == .Title}) {
                        if title.error {
                            Text(title.content)
                                .onTapGesture{
                                    self.vm.regenerateOutput(index: self.index, output: title, outputSettings: title.settings)
                                }
                        } else {
                            Text(title.content).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -30)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color(.systemBackground))
                        }
                    }
                }
                ForEach(sortOutputs(vm.recordingsList[index].outputs).filter { $0.type != .Title && $0.type != .Transcript }.indices, id: \.self) { idx in
                    let output = sortOutputs(vm.recordingsList[index].outputs).filter { $0.type != .Title && $0.type != .Transcript }[idx]
                    VStack(alignment: .leading){
                        OutputView(output: output, recording: vm.recordingsList[index], recordingURL: recordingURL, vm: vm, index: index)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))
                }
                .onDelete{indexSet in
                    indexSet.sorted(by: >).forEach{i in
                        let output = sortOutputs(vm.recordingsList[index].outputs).filter { $0.type != .Title && $0.type != .Transcript}[i]
                        vm.deleteOutput(index: index, output: output)
                    }
                }
                if vm.recordingsList[index].outputs.contains(where: {$0.type == .Transcript}) {
                    let output = vm.recordingsList[index].outputs.first(where: { $0.type == .Transcript})
                    VStack(alignment: .leading){
                        OutputView(output: output!, recording: vm.recordingsList[index], recordingURL: recordingURL, vm: vm, index: index)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))
                }
            }
            
            
            .onReceive(vm.recordingsList[index].$outputs){ outputs in
                print("-- onReceive new update --")
                print(outputs)
            }
            .navigationBarItems(trailing: HStack{
                Menu {
                    Button(action: {
                        let transcript = vm.recordingsList[index].outputs.first { $0.type == .Transcript }?.content ?? ""
                        let filename = "\(vm.recordingsList[index].title).txt"
                        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                        let fileURL = tempDirectoryURL.appendingPathComponent(filename)

                        do {
                           try transcript.write(to: fileURL, atomically: true, encoding: .utf8)
                        } catch {
                           print("Failed to create file")
                           print("\(error)")
                        }
                       
                        activeSheet = .exportText(fileURL)
                    }) {
                        Label("Export Transcript", systemImage: "doc.text")
                    }
                    
                    Button(action: {
                        let originalURL = vm.getAudioURL(filePath: vm.recordingsList[index].filePath)
                        let filename = "\(vm.recordingsList[index].title).m4a"
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
                    }) {
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
                
                EditButton()
            })
            
        }

        .listStyle(.plain)
        .sheet(isPresented: $isShowingCustomOutput){
            CustomOutputSheet(vm: vm, index: index)
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
    }
    
    func sortOutputs(_ outputs: [Output]) -> [Output] {
        return outputs.sorted { $0.type < $1.type }
    }
    
}

struct OutputView: View {
    @ObservedObject var output: Output
    var recording: ObservableRecording
    var recordingURL: URL
    @State private var isMinimized: Bool = false // Add this state variable
    var vm: VoiceViewModel // add this
    var index: Int // add this
    @ObservedObject var cache = OutputCache<String, Bool>()

    
    init(output: Output, recording: ObservableRecording, recordingURL: URL, vm: VoiceViewModel, index: Int) {
           self.output = output
           self.recording = recording
           self.recordingURL = recordingURL
           self.vm = vm
           self.index = index
           var key = "\(recordingURL.lastPathComponent)_\(output.type.rawValue)"

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
                Text(output.type != .Custom ? output.type.rawValue : output.settings.name).font(.headline).padding(.vertical)
                    .padding(.top, 5)
            }
            .padding(.vertical)
            .frame(height: 40)
            .onTapGesture {
                self.isMinimized.toggle()
                var key = "\(recordingURL.lastPathComponent)_\(output.type.rawValue)"
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
                           vm.regenerateOutput(index: index, output: output, outputSettings: output.settings)
                       }
                       
                   }
                }.animation(.easeInOut.speed(1.25))
                // TODO: why, in recently deleted, is output.loading = true when it should be false with content update??
            } else if output.loading && output.content == "Loading" {
                Group {
                   if !isMinimized {
                       HStack{
                           ProgressView().scaleEffect(0.8, anchor: .center) // Scale effect to make spinner a bit larger
                           ZStack {
                               Text(output.content)
                           }
                       }
                   }
                }.animation(.easeInOut.speed(1.25))
            } else {
                Group {
                   if !isMinimized {
                       ZStack {
                           TextEditor(text: $output.content)
                               .font(.body)
                           Text(output.content).opacity(0).padding(.all, 8)
                       }
                   }
                }.animation(.easeInOut.speed(1.25))
            }
            
        }
        .onChange(of: output.content, perform: { value in
           saveRecording()
       })
       
    }
    
    private func saveRecording() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601 // to properly encode the Date field
        do {
            let data = try encoder.encode(recording)
            try data.write(to: recordingURL)
            print("saved changes to disk")
        } catch {
            print("An error occurred while saving the recording object: \(error)")
        }
    }
    
}

struct CustomOutputSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var customPrompt: String = ""
    @State private var customName: String = ""
    
    var vm: VoiceViewModel // add this
    var index: Int // add this

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
                        vm.generateCustomOutput(index: index, outputSettings: currentOutputSettings)
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


