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
    case normal = "None"
    case summary = "Summaries"
    case action = "To-Dos"
}


struct FolderView: View {
    var folder: Folder
    @ObservedObject var vm: VoiceViewModel
    @State var selection: FolderPageEnum = .action
    @State private var isShowingSettings = false
    @State private var searchText = ""

    
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
                        }.pickerStyle(SegmentedPickerStyle())
                        Text("\(vm.recordingsList.count) items")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    ForEach(vm.recordingsList.indices, id: \.self) { idx in
                        Section(){
                                HStack{
                                    
                                    VStack(alignment:.leading) {
                                        Text("Name").font(.headline)
                                        Text("Time").font(.caption)
                                    }
                                    Spacer()
                                    NavigationLink(destination: RecordingView(vm: vm, index: idx)) {
                                    }
                                    
                                }
                                
                                HStack {
                                    if selection == .normal{
                                        Button(action: {
                                            //                                        vm.deleteRecording(folderPath: folder.path, url: vm.recordingsList[idx].fileURL)
                                        }) {
                                            Image(systemName:"x.circle")
                                                .font(.system(size:20))
                                        }
                                        Spacer()
                                        
                                        Button(action: {
                                            if vm.recordingsList[idx].isPlaying == true {
                                                vm.stopPlaying(url: vm.recordingsList[idx].fileURL)
                                            }else{
                                                vm.startPlaying(url: vm.recordingsList[idx].fileURL)
                                            }
                                        }) {
                                            Image(systemName: vm.recordingsList[idx].isPlaying ? "stop.fill" : "play.fill")
                                                .font(.system(size:20))
                                        }
                                        Spacer()
                                    }
                                    if selection == .action {
                                        Text("Action").font(.body)
                                    }
                                    
                                    if selection == .summary {
                                        Text("Summary").font(.body)
                                    }
                                }
                            
                        }
                            
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
                }.searchable(text: $searchText)
            }
            .onReceive(vm.$recordingsList) { updatedList in
                print("** LIST UPDATE IN FOLDER VIEW **.")
                print(vm.recordingsList)
            }.listStyle(.sidebar)
        
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
