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
 - raw audio file
 - title (asynchronous)
 - list of outputs (asynchronous), defaults being:
    - Transcript
    - Summary
    - TODO
 
 Note:
    - each output should be generated based on user global settings. User can
    add new default outputs (premium feature) and can tweak the length,style,format of outputs
 
 Implementation:
    - I am handed the raw audio data
    - save the raw audio data + generic title first in data obj, leave outputs blank
        - make sure to save inside the folder
    - put in an background job to generate title + outputs
    - as jobs finish, update the saved data obj.
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
            Text(folder.name)
                .font(.title)
                .padding()
            
            Text("\(vm.recordingsList.count) items")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding()
            
            // TODO: Display items inside the folder here
            ScrollView(showsIndicators: false){
                ForEach(vm.recordingsList, id: \.createdAt) { recording in
                    VStack{
                        HStack{
                            Image(systemName:"headphones.circle.fill")
                                .font(.system(size:50))
                            
                            VStack(alignment:.leading) {
                                Text("\(recording.fileURL.lastPathComponent)")
                            }
                            VStack {
                                Button(action: {
                                    vm.deleteRecording(url:recording.fileURL)
                                }) {
                                    Image(systemName:"xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size:15))
                                }
                                Spacer()
                                
                                Button(action: {
                                    if recording.isPlaying == true {
                                        vm.stopPlaying(url: recording.fileURL)
                                    }else{
                                        vm.startPlaying(url: recording.fileURL)
                                    }
                                }) {
                                    Image(systemName: recording.isPlaying ? "stop.fill" : "play.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size:30))
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
        .navigationTitle(folder.name)
    }
}

