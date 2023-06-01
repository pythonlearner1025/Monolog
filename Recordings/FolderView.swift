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
    @State var selection: FolderPageEnum = .normal
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
                                ForEach(vm.recordingsList[idx].outputs) {output in
                                    switch output.type {
                                    case .Summary: EmptyView()
                                    case .Action: EmptyView()
                                    case .Transcript: Text(output.content).font(.body)
                                    case .Title: EmptyView()
                                    }
                                }.onAppear{
                                    print(vm.recordingsList[idx].outputs)
                                }
                                
                                HStack {
                                    Text(vm.recordingsList[idx].currentTime)
                                            .font(.caption.monospacedDigit())

                                        // this is a dynamic length progress bar
                                        GeometryReader { gr in
                                            Capsule()
                                                .stroke(Color.black, lineWidth: 2)
                                                .background(
                                                    Capsule()
                                                        .frame(width: gr.size.width * vm.recordingsList[idx].progress,
                                                                  height: 8), alignment: .leading)
                                        }
                                        .frame( height: 8)

                                        Text(vm.recordingsList[idx].totalTime)
                                            .font(.caption.monospacedDigit())
                                }
                                .padding()
                                
                                HStack{

                                    Spacer()
                                    
                                    Button(action: {
                                        vm.backwards15(index: idx, url: vm.recordingsList[idx].fileURL)
                                    }){
                                        Image(systemName: "gobackward.15")
                                            .font(.title)
                                            .imageScale(.medium)
                                    }.buttonStyle(.borderless)
                                    
                                    Button(action: {
                                        if vm.recordingsList[idx].isPlaying == true {
                                            vm.stopPlaying(index: idx, url: vm.recordingsList[idx].fileURL)
                                        }else{
                                            vm.startPlaying(index: idx, url: vm.recordingsList[idx].fileURL)
                                        }}) {
                                        Image(systemName: vm.recordingsList[idx].isPlaying ? "stop.fill" : "play.fill")
                                                .font(.title)
                                                .imageScale(.medium)
                                    }.buttonStyle(.borderless)
                                    
                                    Button(action: {
                                        vm.forward15(index: idx, url: vm.recordingsList[idx].fileURL)
                                    }){
                                        Image(systemName: "goforward.15")
                                            .font(.title)
                                            .imageScale(.medium)
                                    }.buttonStyle(.borderless)
                                    
                                    Spacer()
                                } .onAppear(perform: {
                                    print("// On appear play button //")
                                    print(vm.recordingsList[idx].fileURL)
                                })
                            }
                        }
                        if selection == .action {
                            ForEach(vm.recordingsList[idx].outputs) {output in
                                switch output.type {
                                case .Summary: EmptyView()
                                case .Action: Text(output.content).font(.body)
                                case .Transcript: EmptyView()
                                case .Title: EmptyView()
                                }
                            }
                        }
                        
                        if selection == .summary {
                            ForEach(vm.recordingsList[idx].outputs) {output in
                                switch output.type {
                                case .Summary: Text(output.content).font(.body)
                                case .Action: EmptyView()
                                case .Transcript: EmptyView()
                                case .Title: EmptyView()
                                }
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
