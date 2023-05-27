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


struct FolderView: View {
    var folder: Folder
    @ObservedObject var vm: VoiceViewModel
    
    init(folder: Folder) {
        self.folder = folder
        self.vm = VoiceViewModel(folderPath: folder.path)
    }
    
    var body: some View {
        VStack {
            Text("\(vm.recordingsList.count) items")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding()
            
            // TODO: Display items inside the folder here
            ScrollView(showsIndicators: false){
                ForEach(vm.recordingsList.indices, id: \.self) { idx in
                    VStack{
                        HStack{
                            Image(systemName:"headphones.circle.fill")
                                .font(.system(size:50))
                            
                            VStack(alignment:.leading) {
                                Text("\(vm.recordingsList[idx].fileURL.lastPathComponent)")
                            }
                            VStack {
                                Button(action: {
                                    vm.deleteRecording(folderPath: folder.path, url: vm.recordingsList[idx].fileURL)
                                }) {
                                    Image(systemName:"xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size:15))
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
                                        .foregroundColor(.white)
                                        .font(.system(size:30))
                                }
                                
                                NavigationLink(destination: RecordingView(vm: vm, index: idx)) {
                                    VStack(alignment: .leading) {
                                        Text("View recording")
                                    }
                                }
                            }
                        }.padding()
                    }.padding(.horizontal,10)
                        .frame(width: 370, height: 85)
                        .background(Color(#colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1)))
                        .cornerRadius(30)
                        .shadow(color: Color(#colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)).opacity(0.3), radius: 10, x: 0, y: 10)
                }
            }
            
            Image(systemName: vm.isRecording ? "stop.circle.fill" : "mic.circle.fill")
            .foregroundColor(.red)
            .font(.system(size: 45))
            .onTapGesture {
                if vm.isRecording == true {
                    vm.stopRecording(folderPath: folder.path)
                } else {
                    vm.startRecording(folderPath: folder.path)
                }
            }
            
            
        }
        .onReceive(vm.$recordingsList) { updatedList in
            print("** LIST UPDATE IN FOLDER VIEW **.")
            print(vm.recordingsList)
        }
        .navigationTitle(folder.name)
    }
}
