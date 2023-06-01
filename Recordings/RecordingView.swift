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
    @State private var showingSheet = false
    @State private var selectedLength = ""
    @State private var selectedTone = ""
    @State private var selectedFormat = ""
    @State private var customInput = ""
    
    var index: Int
    var recordingURL: URL
    var body: some View {
        NavigationStack{
            List(sortOutputs(vm.recordingsList[index].outputs).indices, id: \.self) { idx in
                VStack(alignment: .leading){
                    let output = sortOutputs(vm.recordingsList[index].outputs)[idx]
                    switch  output.type {
                        case .Summary:
                            OutputView(output: output, recording: vm.recordingsList[index], recordingURL: recordingURL)
                        case .Action:
                            OutputView(output: output, recording: vm.recordingsList[index], recordingURL: recordingURL)
                        case .Transcript:
                            OutputView(output: output, recording: vm.recordingsList[index], recordingURL: recordingURL)
                        case .Title:
                            Text(output.content).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 5)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.systemBackground))

            }
            .navigationBarItems(trailing: HStack{
                ShareLink(item: "Google.com"){
                    Image(systemName: "square.and.arrow.up")
                }
                Button(action: {}){
                    Image(systemName: "gearshape")
                }
            })
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar){
                    Image(systemName: "plus.circle")
                        .font(.system(size: 50, weight: .thin))
                        .onTapGesture {
                            showingSheet.toggle()
                        }.sheet(isPresented: $showingSheet){
                            SheetView(selectedLength: $selectedLength, selectedTone: $selectedTone, selectedFormat: $selectedFormat, customInput: $customInput)
                        }
                }
            }
            .listStyle(.plain)
           
        }
        
    
        // TODO: this causes crash
        func sortOutputs(_ outputs: [Output]) -> [Output] {
            return outputs.sorted { $0.type < $1.type }
        }
    }

// TODO: save on disk changes to text
struct OutputView: View {
    @ObservedObject var output: Output
    var recording: ObservableRecording
    var recordingURL: URL
    @State private var isMinimized: Bool = false // Add this state variable

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: isMinimized ? "chevron.forward" : "chevron.down")
                Text(output.type.rawValue).font(.headline).padding(.vertical)
                    .padding(.top, 5)
            }
            .padding(.vertical)
            .frame(height: 40)
            .onTapGesture {
                self.isMinimized.toggle()
            }

            Group {
               if !isMinimized {
                   ZStack {
                       TextEditor(text: $output.content)
                           .font(.body)
                    
                       Text(output.content).opacity(0).padding(.all, 8)
                   }
               }
            }
            .animation(.easeInOut.speed(1.25))
        }
        .onChange(of: output.content, perform: { value in
           // This block will be called whenever `output.content` changes.
           // Insert your function call here.
           print("output.content changed to: \(value)")
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

// TODO: sheet should be equal to settings except custom input
struct SheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedLength: String
    @Binding var selectedTone: String
    @Binding var selectedFormat: String
    @Binding var customInput: String
    
    let lengthOptions = ["Short", "Medium", "Long"]
    let toneOptions = ["Option 1", "Option 2", "Option 3", "Option 4", "Option 5"]
    let formatOptions = ["Option A", "Option B", "Option C", "Option D", "Option E"]
    
    var body: some View{
        NavigationStack {
                Form {
                    Section(header: Text("Length")) {
                        Picker("Select Length", selection: $selectedLength) {
                            ForEach(lengthOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Tone")) {
                        Picker("Select Tone", selection: $selectedTone) {
                            ForEach(toneOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(DefaultPickerStyle())
                    }
                    
                    Section(header: Text("Format")) {
                        Picker("Select Format", selection: $selectedFormat) {
                            ForEach(formatOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(DefaultPickerStyle())
                    }
                    
                    Section(header: Text("Custom Input")) {
                        TextEditor(text: $customInput)
                            .frame(height: 100)
                    }
                    
                    Button("Submit") {
                        // Perform submission logic here
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
    }
}


