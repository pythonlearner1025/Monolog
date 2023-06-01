//
//  FolderView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all recordings

import SwiftUI
import AVFoundation

// recordings struct
/*
    TODO: https://chat.openai.com/c/4541f437-7a4a-447e-b976-a36893e564a5
    //stuck in getting recordingList to auto-refresh. made it into an observableObject,
    but no luck.
 
 */

enum FolderPageEnum: String, CaseIterable {
    case normal = "Transcript"
    case summary = "Summary"
    case action = "Action Items"
}


struct FolderView: View {
    var folder: Folder
    @ObservedObject var vm: VoiceViewModel
    @State var selection: FolderPageEnum = .action
    @State private var isShowingSettings = false
    @State private var searchText = ""
    var formatter = DateComponentsFormatter()
    
    init(folder: Folder) {
        self.folder = folder
        self.vm = VoiceViewModel(folderPath: folder.path)
    }
    
    var body: some View {
        NavigationStack{
            
            // TODO: Display items inside the folder here
            List{
                VStack{
                    
                    Picker(selection: $selection, label: Text("")){
                        ForEach(FolderPageEnum.allCases, id: \.self){ option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .listRowInsets(.init())
                    .listRowBackground(Color(.secondarySystemBackground))
                    
                }
                ForEach(vm.recordingsList.indices, id: \.self) { idx in
                    
                    HStack{
                        VStack(alignment:.leading) {
                            Text("\(vm.recordingsList[idx].title)").font(.headline)
                            Text("\(vm.recordingsList[idx].createdAt)").font(.caption)
                        }
                        Spacer()
                        NavigationLink(destination: RecordingView(vm: vm, index: idx, recordingURL: getRecordingURL(fileURL: vm.recordingsList[idx].fileURL))) {
                        }
                        
                    }.listRowSeparator(.hidden)
                    
                    
                    VStack {
                        if selection == .normal{
                            
                            VStack{
                                List(vm.recordingsList[idx].outputs) {output in
                                    switch output.type {
                                    case .Summary: Text("")
                                    case .Action: Text("")
                                    case .Transcript: Text(output.content).font(.body)
                                    case .Title: Text("")
                                    }
                                }
                                
//                               Slider(value: $vm.recordingsList[idx].currentTime, in: 0...vm.recordingsList[idx].totalTime)
                                if(true){
                                    Text("\(vm.recordingsList[idx].currentTime)")
                                    Text("\(vm.recordingsList[idx].totalTime)")
                                    Text("\(vm.recordingsList[idx].test)")
                                }
                                
                                HStack{
//                                    Button(action: {
//                                        vm.deleteRecording(recordingURL: getRecordingURL(fileURL:  vm.recordingsList[idx].fileURL), fileURL: vm.recordingsList[idx].fileURL)
//                                    }) {
//                                        Image(systemName:"x.circle")
//                                            .font(.system(size:20))
//                                    }
                                    Spacer()
                                    
                                    Button(action: {
                                        if vm.recordingsList[idx].isPlaying == true {
                                            vm.stopPlaying(url: vm.recordingsList[idx].fileURL)
                                        }else{
                                            vm.startPlaying(index: idx, url: vm.recordingsList[idx].fileURL)
//                                            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true){ _ in
//                                                if vm.recordingsList[idx].isPlaying{
//                                                    vm.recordingsList[idx].currentTime = vm.audioPlayer.currentTime
//                                                }
//                                            }
                                        }
                                        
                                    }) {
                                        Image(systemName: vm.recordingsList[idx].isPlaying ? "stop.fill" : "play.fill")
                                            .font(.system(size:20))
                                    }
                                    Spacer()
                                }
                            }
                        }
                        if selection == .action {
                            List(vm.recordingsList[idx].outputs) {output in
                                switch output.type {
                                case .Summary: Text("")
                                case .Action: Text(output.content).font(.body)
                                case .Transcript: Text("")
                                case .Title: Text("ERROR")
                                }
                            }
                        }
                        
                        if selection == .summary {
                            List(vm.recordingsList[idx].outputs) {output in
                                switch output.type {
                                case .Summary: Text(output.content).font(.body)
                                case .Action: Text("")
                                case .Transcript: Text("")
                                case .Title: Text("ERROR")
                                }
                            }
                        }
                    }.listRowSeparator(.hidden)
                    
                    
                    
                }
            }.sheet(isPresented: $isShowingSettings){
                SettingsView()
            }.navigationTitle("\(folder.name)")
                .navigationBarItems(trailing: HStack{
                    ShareLink(item: "Google.com"){
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button(action: {isShowingSettings.toggle()}){
                        Image(systemName: "gearshape")
                    }
                }).toolbar{
                    ToolbarItem(placement: .bottomBar){
                        Image(systemName: vm.isRecording ? "stop.circle.fill" : "mic.circle")
                            .foregroundColor(.red)
                            .font(.system(size: 50, weight: .thin))
                            .onTapGesture {
                                if vm.isRecording == true {
                                    vm.stopRecording(folderPath: folder.path)
                                } else {
                                    vm.startRecording(folderPath: folder.path)
                                }
                            }
                    }
                }
        }
        .onReceive(vm.$recordingsList) { updatedList in
            print("** LIST UPDATE IN FOLDER VIEW **.")
            print(vm.recordingsList)
        }.listStyle(.plain)
        
    }

    func getRecordingURL(fileURL: URL) -> URL {
        let folderURL = URL(fileURLWithPath: folder.path)
        return folderURL.appendingPathComponent("\(fileURL.lastPathComponent).json")
    }
}



struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode1
    
    @State private var selectedFormat = FormatType.bullet
    @State private var selectedLength = LengthType.short
    @State private var selectedStyle = StyleType.casual
    
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
                    Picker("Select Length", selection: $selectedLength) {
                        ForEach(FormatType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Style")) {
                    Picker("Select Length", selection: $selectedLength) {
                        ForEach(StyleType.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Button("Save") {
                    // Perform submission logic here
                }
            }
            .navigationBarTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode1.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
