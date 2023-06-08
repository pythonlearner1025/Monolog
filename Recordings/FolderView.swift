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
    var folder: RecordingFolder
    @ObservedObject var vm: VoiceViewModel
    @ObservedObject private var keyboardResponder = KeyboardResponder()
    @State var selection: FolderPageEnum = .normal
    @State private var isShowingSettings = false
    @State private var isShowingPicker = false
    @State private var searchText = ""
    @State private var formHasAppeared = false


    init(folder: RecordingFolder) {
        self.folder = folder
        self.vm = VoiceViewModel(folderPath: folder.path)
    }
    
    var body: some View {
        NavigationStack{
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
                    VStack (alignment: .leading){
                        HStack{
                            VStack(alignment:.leading) {
                                Text("\(vm.recordingsList[idx].title)").font(.headline)
                                Text("\(formatter.string(from: vm.recordingsList[idx].createdAt))").font(.caption).foregroundColor(Color(.gray))

                            }.padding(.bottom, 10)
                            Spacer()
                            NavigationLink(destination: RecordingView(vm: vm, os: vm.recordingsList[idx].outputs, index: idx, recordingURL: getRecordingURL(filePath: vm.recordingsList[idx].filePath))) {
                                
                            }
                        }
                        VStack (alignment: .leading) {
                            if selection == .normal{
                                ForEach(vm.recordingsList[idx].outputs.outputs) {output in
                                    switch output.type {
                                    case .Summary: EmptyView()
                                    case .Action: EmptyView()
                                    case .Transcript: OutputPreview(output: output)
                                    case .Title: EmptyView()
                                    case .Custom: EmptyView()
                                    }
                                }
                            }
                            if selection == .action {
                                ForEach(vm.recordingsList[idx].outputs.outputs) {output in
                                    switch output.type {
                                    case .Summary: EmptyView()
                                    case .Action: OutputPreview(output: output)
                                    case .Transcript: EmptyView()
                                    case .Title: EmptyView()
                                    case .Custom: EmptyView()
                                    }
                                }
                            }
                            if selection == .summary {
                                ForEach(vm.recordingsList[idx].outputs.outputs) {output in
                                    switch output.type {
                                    case .Summary: OutputPreview(output: output)
                                    case .Action: EmptyView()
                                    case .Transcript: EmptyView()
                                    case .Title: EmptyView()
                                    case .Custom: EmptyView()
                                    }
                                }
                            }
                        }
                        
                    }
                    .id(UUID())
                    HStack {
                        Text(vm.recordingsList[idx].currentTime)
                            .font(.caption.monospacedDigit())
                        Slider(value: $vm.recordingsList[idx].absProgress, in: 0...vm.recordingsList[idx].duration).accentColor(Color.primary)
                        Text(vm.recordingsList[idx].totalTime)
                            .font(.caption.monospacedDigit())
                    }
                    .padding()
                    AudioControlView(vm: vm, idx: idx)
                    Divider().padding(.vertical, 15)  // Add a divider here
                }
                .onDelete{indexSet in
                    indexSet.sorted(by: >).forEach{ i in
                        vm.stopPlaying(index: i)
                        vm.deleteRecording(audioPath: vm.recordingsList[i].filePath)
                    }
                    vm.recordingsList.remove(atOffsets: indexSet)
                }
                .listRowSeparator(.hidden)
                //.searchable(text: $searchText)

            }
            .onAppear { formHasAppeared = true }
            .if(formHasAppeared) { view in
                view.searchable(text: $searchText)
            }
            .sheet(isPresented: $isShowingSettings){
                if let outputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") {
                    SettingsView(selectedFormat: outputSettings.format, selectedLength: outputSettings.length, selectedTone: outputSettings.tone)
                }
            }
            .navigationTitle("\(folder.name)")
            .navigationBarItems(trailing: HStack{
                // TODO: import audio
                Button(action: {
                    isShowingPicker = true
                }) {
                    Image(systemName: "square.and.arrow.down") // This is a system symbol for uploading.
                }
                Button(action: {isShowingSettings.toggle()}){
                    Image(systemName: "gearshape")
                }
                EditButton()
            })
        }
        .onChange(of: vm.recordingsList.count) { newCount in
            print("** #FILES: \(newCount) **")
            folder.count = newCount
        }
        .listStyle(.plain)
        .fileImporter(isPresented: $isShowingPicker, allowedContentTypes: [.audio]) {(res) in
            do {
                let fileURL = try res.get()
                if fileURL.startAccessingSecurityScopedResource() {
                    vm.saveImportedRecording(filePath: fileURL)
                    fileURL.stopAccessingSecurityScopedResource()
                }
            } catch {
                print("error reading file")
            }
        }
    
        if (folder.name != "Recently Deleted" && keyboardResponder.currentHeight == 0) {
            HStack {
                    Spacer()
                   CameraButtonView(action: { isRecording in
                       print(isRecording)
                       if isRecording == true {
                           vm.stopRecording()
                       } else {
                           vm.startRecording()
                       }
                   })
                    Spacer()
               }
               .background(Color(.secondarySystemBackground)) // Background color of the toolbar
               .edgesIgnoringSafeArea(.bottom)
               .padding(.top, -10)
        }
    }

    func getRecordingURL(filePath: String) -> URL {
        let folderURL = URL(fileURLWithPath: folder.path)
        return folderURL.appendingPathComponent("\(filePath).json")
    }
    
    private let formatter: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "EEEE, MMMM d, yyyy"
         return formatter
     }()
    
    private var filteredItems: [ObservableRecording] {
        if searchText.isEmpty {
            return vm.recordingsList
        }
        else{
            return vm.recordingsList.filter {item in
                item.title.localizedCaseInsensitiveContains(searchText)
                // TODO: search through all output.content text
            }
        }
    }
}

struct OutputPreview: View {
    @State var output: Output
    var body: some View {
        if output.error {
            HStack{
                // TODO: show error sign
                Image(systemName: "exclamationmark.arrow.circlepath")
                ZStack {
                    Text(output.content).foregroundColor(.gray)
                }
            }
        } else if output.loading && output.content == "Loading" {
            HStack{
                ProgressView().scaleEffect(0.8, anchor: .center).padding(.trailing, 5) // Scale effect to make spinner a bit larger
                ZStack {
                    Text(output.content)
                        .font(.body).foregroundColor(.gray)
                }
            }
        } else {
            Text(output.content).font(.body).lineLimit(4).truncationMode(.tail)
        }
    }
}

struct AudioControlView: View {
    @ObservedObject var vm: VoiceViewModel
    var idx: Int
    
    var body: some View {
        HStack{
            Spacer()
            /*
            Button(action: {
                vm.backwards15(index: idx, filePath: vm.recordingsList[idx].filePath)
            }){
                Image(systemName: "gobackward.15")
                    .font(.title)
                    .imageScale(.small)
                    .foregroundColor(.primary)
                    .padding(.trailing, 20)
            }.buttonStyle(.borderless)
            */
            Button(action: {
                if vm.recordingsList[idx].isPlaying == true {
                    vm.stopPlaying(index: idx)
                }else{
                    vm.startPlaying(index: idx, filePath: vm.recordingsList[idx].filePath)
                }}) {
                    Image(systemName: vm.recordingsList[idx].isPlaying ? "stop.fill" : "play.fill")
                        .font(.title)
                        .imageScale(.large)
                        .foregroundColor(.primary)
                }.buttonStyle(.borderless)
            /*

            Button(action: {
                vm.forward15(index: idx, filePath: vm.recordingsList[idx].filePath)
            }){
                Image(systemName: "goforward.15")
                    .font(.title)
                    .imageScale(.small)
                    .foregroundColor(.primary)
                    .padding(.leading, 20)
            }.buttonStyle(.borderless)
             */
            Spacer()
        }
    }
}

struct SettingsView: View {
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
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
