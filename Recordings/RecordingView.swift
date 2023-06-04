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
            if !vm.recordingsList[index].outputs.contains(where: {$0.type == .Title}) {
                Text(vm.recordingsList[index].title).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -60)
            } else {
                if let title = vm.recordingsList[index].outputs.first(where: {$0.type == .Title}) {
                    if title.error {
                        Text(title.content)
                            .onTapGesture{
                                self.vm.regenerateOutput(index: self.index, output: title, outputSettings: title.settings)
                            }
                    } else {
                        Text(title.content).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -60)
                    }
                }
            }
            List{
                ForEach(sortOutputs(vm.recordingsList[index].outputs).indices, id: \.self) { idx in
                    VStack(alignment: .leading){
                        let output = sortOutputs(vm.recordingsList[index].outputs)[idx]
                        switch  output.type {
                        case .Summary:
                            OutputView(output: output, recording: vm.recordingsList[index], recordingURL: recordingURL, vm: vm, index: index)
                        case .Action:
                            OutputView(output: output, recording: vm.recordingsList[index], recordingURL: recordingURL, vm: vm, index: index)
                        case .Transcript:
                            OutputView(output: output, recording: vm.recordingsList[index], recordingURL: recordingURL, vm: vm, index: index)
                        case .Custom:
                            OutputView(output: output, recording: vm.recordingsList[index], recordingURL: recordingURL, vm: vm, index: index)
                        case .Title:
                            EmptyView()
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))
                    
                }
                .onDelete{indexSet in
                    indexSet.sorted(by: >).forEach{i in
                        let output = sortOutputs(vm.recordingsList[index].outputs)[i]
                        vm.deleteOutput(index: index, output: output)
                    }
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
                Button(action: {isShowingSettings.toggle()}){
                    Image(systemName: "gearshape")
                }
                EditButton()
            })
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar){
                Image(systemName: "circle")
                    .font(.system(size: 50, weight: .thin))
                    .overlay(
                        Image(systemName: "sparkles")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .foregroundColor(.primary), alignment: .center
                    )
                    .onTapGesture {
                        isShowingCustomOutput.toggle()
                    }
            }
        }

        .listStyle(.plain)
        .sheet(isPresented: $isShowingCustomOutput){
            CustomOutputSheet(vm: vm, index: index)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
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
    @Binding var isMinimized: Bool
    
    // TODO: "remember" whether it was minimized or not when deleting. 
    @State private var isMinimized: Bool = false // Add this state variable
    
    var vm: VoiceViewModel // add this
    var index: Int // add this

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
           // This block will be called whenever `output.content` changes.
           // Insert your function call here.
           //print("output.content changed to: \(value)")
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

// TODO: save user's last options
struct CustomOutputSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedLength: LengthType = LengthType.short
    @State private var selectedFormat: FormatType = FormatType.bullet
    @State private var selectedTone: ToneType = ToneType.casual
    @State private var customInput: String = ""
    @State private var customName: String = ""
    
    var vm: VoiceViewModel // add this
    var index: Int // add this

    var body: some View{
        NavigationStack {
                Form {
                    Section(header: Text("Length")) {
                        Picker("Select Length", selection: $selectedLength) {
                            ForEach(LengthType.allCases, id: \.self) { option in
                                Text(option.rawValue)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Tone")) {
                        Picker("Select Format", selection: $selectedFormat) {
                            ForEach(FormatType.allCases, id: \.self) { option in
                                Text(option.rawValue)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Format")) {
                        Picker("Select Tone", selection: $selectedTone) {
                            ForEach(ToneType.allCases, id: \.self) { option in
                                Text(option.rawValue)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Custom Name")) {
                        TextEditor(text: $customName)
                            .frame(height: 20)
                    }
                    
                    Section(header: Text("Custom Prompt")) {
                        TextEditor(text: $customInput)
                            .frame(height: 100)
                    }
                    
                    Button("Submit") {
                        // Perform submission logic here
                        let currentOutputSettings = OutputSettings(length: selectedLength, format: selectedFormat, tone: selectedTone, prompt: customInput, name: customName)
                        vm.generateCustomOutput(index: index, outputSettings: currentOutputSettings)
                        UserDefaults.standard.storeOutputSettings(currentOutputSettings, forKey: "Output Settings")
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .navigationBarTitle("Custom Output")
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
                self.selectedLength = outputSettings.length
                self.selectedTone = outputSettings.tone
                self.selectedFormat = outputSettings.format
                self.customInput = outputSettings.prompt
                self.customName = outputSettings.name
            }
        }
    }
}


