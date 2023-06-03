//
//  FolderView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all recordings

import SwiftUI
import AVFoundation

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
                ForEach(filteredItems.indices, id: \.self) { idx in
                    VStack{
                        HStack{
                            VStack(alignment:.leading) {
                                Text("\(vm.recordingsList[idx].title)").font(.headline)
                                Text("\(vm.recordingsList[idx].createdAt)").font(.caption)
                            }
                            Spacer()
                            NavigationLink(destination: RecordingView(vm: vm, index: idx, recordingURL: getRecordingURL(filePath: vm.recordingsList[idx].filePath))) {
                                
                            }
                        }.listRowSeparator(.hidden)
                        
                        
                        VStack {
                            if selection == .normal{
                                
                                VStack{
                                    ForEach(vm.recordingsList[idx].outputs) {output in
                                        switch output.type {
                                        case .Summary: EmptyView()
                                        case .Action: EmptyView()
                                        case .Transcript: Text(output.content).font(.body).lineLimit(4).truncationMode(.tail)
                                        case .Title: EmptyView()
                                        case .Custom: EmptyView()
                                        }
                                    }.onAppear{
                                        //print(vm.recordingsList[idx].outputs)
                                    }
                                    
                                    HStack {
                                        Text(vm.recordingsList[idx].currentTime)
                                            .font(.caption.monospacedDigit())
                                        
                                        Slider(value: $vm.recordingsList[idx].absProgress, in: 0...vm.recordingsList[idx].duration).accentColor(Color.primary)
                                        // this is a dynamic length progress bar
//                                        GeometryReader { gr in
//                                            Capsule()
//                                                .stroke(Color.black, lineWidth: 2)
//                                                .background(
//                                                    Capsule()
//                                                        .frame(width: gr.size.width * vm.recordingsList[idx].progress,
//                                                               height: 8), alignment: .leading)
//                                        }
//                                        .frame( height: 8)
                                        
                                        Text(vm.recordingsList[idx].totalTime)
                                            .font(.caption.monospacedDigit())
                                    }
                                    .padding()
                                    
                                    HStack{
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            vm.backwards15(index: idx, filePath: vm.recordingsList[idx].filePath)
                                        }){
                                            Image(systemName: "gobackward.15")
                                                .font(.title)
                                                .imageScale(.small)
                                                .foregroundColor(.primary)
                                        }.buttonStyle(.borderless)
                                        
                                        Button(action: {
                                            if vm.recordingsList[idx].isPlaying == true {
                                                vm.stopPlaying(index: idx)
                                            }else{
                                                vm.startPlaying(index: idx, filePath: vm.recordingsList[idx].filePath)
                                            }}) {
                                                Image(systemName: vm.recordingsList[idx].isPlaying ? "stop.fill" : "play.fill")
                                                    .font(.title)
                                                    .imageScale(.medium)
                                                    .foregroundColor(.primary)
                                            }.buttonStyle(.borderless)
                                        
                                        Button(action: {
                                            vm.forward15(index: idx, filePath: vm.recordingsList[idx].filePath)
                                        }){
                                            Image(systemName: "goforward.15")
                                                .font(.title)
                                                .imageScale(.small)
                                                .foregroundColor(.primary)
                                        }.buttonStyle(.borderless)
                                        
                                        Spacer()
                                    } .onAppear(perform: {
                                        
                                    })
                                }
                            }
                            if selection == .action {
                                ForEach(vm.recordingsList[idx].outputs) {output in
                                    switch output.type {
                                    case .Summary: EmptyView()
                                    case .Action: Text(output.content).font(.body).lineLimit(4).truncationMode(.tail)
                                    case .Transcript: EmptyView()
                                    case .Title: EmptyView()
                                    case .Custom: EmptyView()
                                    }
                                }
                            }
                            
                            if selection == .summary {
                                ForEach(vm.recordingsList[idx].outputs) {output in
                                    switch output.type {
                                    case .Summary: Text(output.content).font(.body).lineLimit(4).truncationMode(.tail)
                                    case .Action: EmptyView()
                                    case .Transcript: EmptyView()
                                    case .Title: EmptyView()
                                    case .Custom: EmptyView()
                                        
                                    }
                                }
                            }
                        }
                    }
                    .onAppear{
                        for index in vm.recordingsList.indices { 
                            let updatedRecording = vm.recordingsList[index]
                            vm.recordingsList[index] = updatedRecording
                            print(vm.recordingsList[index].currentTime)
                        }
                    }
                    
                    
                    
            }.onDelete{indexSet in
                indexSet.sorted(by: >).forEach{ i in
                    vm.stopPlaying(index: i)
                    let tempFilePath = vm.recordingsList[i].filePath
                    vm.deleteRecording(recordingURL: vm.getFileURL(filePath: tempFilePath), filePath: tempFilePath)
                }
                vm.recordingsList.remove(atOffsets: indexSet)
                
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
                EditButton()
            }).toolbar{
                ToolbarItem(placement: .bottomBar){
                    Image(systemName: vm.isRecording ? "stop.circle.fill" : "mic.circle")
                        .foregroundColor(.red)
                        .font(.system(size: 50, weight: .thin))
                        .onTapGesture {
                            if vm.isRecording == true {
                                vm.stopRecording()
                            } else {
                                vm.startRecording()
                            }
                        }
                }
            }.searchable(text: $searchText)
        }
        .onChange(of: vm.recordingsList.count) { newCount in
            print("** #FILES: \(newCount) **")
            folder.count = newCount
        }
        .onReceive(vm.$recordingsList) { updatedList in
            //print("** LIST UPDATE IN FOLDER VIEW **.")
            //print(vm.recordingsList)
        }.listStyle(.plain)
        
        
    }

    func getRecordingURL(filePath: String) -> URL {
        let folderURL = URL(fileURLWithPath: folder.path)
        return folderURL.appendingPathComponent("\(filePath).json")
    }
    
    private var filteredItems: [ObservableRecording] {
        if searchText.isEmpty {
            return vm.recordingsList
        }
        else{
            return vm.recordingsList.filter {item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.totalTime.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}



struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode1
    
    @State private var selectedFormat = FormatType.bullet
    @State private var selectedLength = LengthType.short
    @State private var selectedTone = ToneType.casual
    
    var body: some View {
        NavigationStack{
            Form {
                Text("Select the defualt settings that will be used to generate custom outputs from your recordings")
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
                            Text(option.rawValue)
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
