//
//  OutputViews.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import SwiftUI

struct OutputView: View {
    @ObservedObject var output: Output
    @State var isMinimized: Bool = false // Add this state variable
    let audioAPI: AudioRecorderModel = AudioRecorderModel()
    let recording: Recording
    
    init(_ output: Output, recording: Recording) {
       self.output = output
       self.recording = recording
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
                isMinimized.toggle()
            }
            
            switch output.status {
            case.error:
                 Group {
                   if !isMinimized {
                       HStack{
                           // TODO: show error sign
                           Image(systemName: "exclamationmark.arrow.circlepath")
                           ZStack {
                               Text(output.content)
                           }
                       }
                       
                   }
                }.onTapGesture{
                   audioAPI.regenerateOutput(recording: recording, output: output)
                }.animation(.easeInOut.speed(1.4),  value: isMinimized)
            case .loading:
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
            case .completed:
                Group {
                   if !isMinimized {
                       ZStack {
                           TextEditor(text: $output.content)
                               .font(.body)
                           Text(output.content).opacity(0).padding(.all, 8)
                       }
                   }
                }
                .animation(.easeInOut.speed(1.6))
                .onChange(of: output.content, perform: { value in
                   saveRecording()
                })
            case .restricted:
                EmptyView()
            }
        }
    }
    
    private func getCustomOutputName(_ output: Output) -> String{
        let outputs = recording.outputs.outputs
        let dupes = outputs.filter{ $0.settings.name == output.settings.name}
        //print(dupes)
        let pos = dupes.firstIndex(where: {$0.id.uuidString == output.id.uuidString})
        if pos == 0 {
            return output.settings.name
        } else {
            return "\(output.settings.name) (\(pos!.description))"
        }
    }
    
    private func saveRecording() {
        let encoder = Util.encoder()
        do {
            let data = try encoder.encode(recording)
            let folderURL = Util.buildFolderURL(recording.folderPath)
            try data.write(to: folderURL.appendingPathComponent(recording.filePath))
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
        switch output.status {
        case .error:
            HStack{
                Image(systemName: "exclamationmark.arrow.circlepath")
                Text(output.content).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -30).foregroundColor(.gray)
            }
            .onTapGesture{
                audioAPI.regenerateOutput(recording:recording, output:output)
            }
        case .loading:
            HStack{
                ProgressView().scaleEffect(0.8, anchor: .center).padding(.trailing, 5)
                Text(output.content).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -30).foregroundColor(.gray)
            }
        case .completed:
            HStack{
                ZStack {
                    TextEditor(text: $output.content)
                      .font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -30)                    .multilineTextAlignment(.center)

                    Text(output.content).font(.title2.weight(.bold)).padding(.vertical).frame(maxWidth: .infinity, alignment: .center).padding(.top, -30).foregroundColor(.gray).opacity(0)
                    }
            }
            .onChange(of: output.content, perform: { value in
                recording.title = value
                saveRecording()
            })
        case .restricted:
            EmptyView()
        
        }
    }
    
    private func saveRecording() {
        let encoder = Util.encoder()
        do {
            let data = try encoder.encode(recording)
            let folderURL = Util.buildFolderURL(recording.folderPath)
            try data.write(to: folderURL.appendingPathComponent(recording.filePath))
        } catch {
            print("An error occurred while saving the recording object: \(error)")
        }
    }
}

struct CustomOutputView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundColor(.blue)
        }
    }
}
