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
    @ObservedObject var recording: Recording
    @ObservedObject var outputs: Outputs
    @State private var isShowingSettings = false
    @State private var isShowingCustomOutput = false
    @State private var activeSheet: ActiveSheet?
    @State private var selectedLength = ""
    @State private var selectedTone = ""
    @State private var selectedFormat = ""
    @State private var customInput = ""
    @State private var showDelete: Bool = false
    @ObservedObject private var keyboardResponder = KeyboardResponderModel()
    
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
            if keyboardResponder.currentHeight != 0 {
                Spacer()
                Button(action: hideKeyboard) {
                    Text("Done")
                }
            } else {
                Menu {
                    Button(action: exportText) {
                        Label("Export Text", systemImage: "doc.text")
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
                    if !showDelete {
                        Text("Edit")
                    } else {
                        Text("Done")
                    }
                }
            }
        })
        .listStyle(.plain)
        .sheet(isPresented: $isShowingCustomOutput){
            CustomOutputSheet(recording: recording)
        }
        .sheet(isPresented: $isShowingSettings) {
            if let outputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") {
                SettingsSheet(selectedFormat: outputSettings.format, selectedLength: outputSettings.length, selectedTone: outputSettings.tone)
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
        .onReceive(outputs.$outputs){ outputs in
        }
    }
    
    func sortOutputs(_ outputs: [Output]) -> [Output] {
        return outputs.sorted { $0.type < $1.type }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func deleteOutput(_ output: Output){
        if let idxToDelete = outputs.outputs.firstIndex(where: {$0.id == output.id}) {
            outputs.outputs.remove(at: idxToDelete)
            let encoder = Util.encoder()
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
    
    private func exportText() {
        var all = outputs.outputs
            .filter { $0.type != .Title }  // Exclude .Title type
            .map { "\n\($0.type.rawValue)\n\($0.content)" }  // Concatenate title and content with newlines
            .joined(separator: "\n")  // Join all strings into one with a newline separator
        all.removeFirst()
        let filename = "\(recording.title).txt"
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileURL = tempDirectoryURL.appendingPathComponent(filename)

        do {
            try all.write(to: fileURL, atomically: true, encoding: .utf8)
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
