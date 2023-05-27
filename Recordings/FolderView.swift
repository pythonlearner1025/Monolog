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

enum FolderPageEnum {
    case normal
    case summary
    case action
}


struct FolderView: View {
    var folder: Folder
    @ObservedObject var vm: VoiceViewModel
    @State var selection: FolderPageEnum = .action
    
    init(folder: Folder) {
        self.folder = folder
        self.vm = VoiceViewModel(folderPath: folder.path)
    }
    
    var body: some View {
        ZStack{
            LinearGradient(colors:[Color.black, Color.black], startPoint: .top, endPoint: .bottom).opacity(0.25).ignoresSafeArea()
            
            VStack {
                HStack{
                    Spacer()
                    Button(action: {selection = .normal}) {
                        Text("None")
                    }.padding().background(Color.white).cornerRadius(5).frame(width: 125)
                    Spacer()
                    Button(action: {selection = .summary}) {
                        Text("Summaries")
                    }.padding().background(Color.white).cornerRadius(5).frame(width: 125)
                    Spacer()
                    Button(action: {selection = .action}) {
                        Text("To-Dos").fontWeight(.medium)
                    }.padding().background(Color.white).cornerRadius(5).frame(width: 125)
                    Spacer()
                }.padding(.horizontal).padding(.vertical).foregroundColor(Color.black)
                Divider()
                // TODO: Display items inside the folder here
                ScrollView(showsIndicators: false){
                    
                    Text("\(vm.recordingsList.count) items")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    ForEach(vm.recordingsList.indices, id: \.self) { idx in
                        VStack{
                            HStack{
                                
                                VStack(alignment:.leading) {
                                    Text("Name").font(.headline)
                                    Text("Time").font(.caption)
                                }
                                    Spacer()
                                    NavigationLink(destination: RecordingView(vm: vm, index: idx)) {
                                        Image(systemName:"chevron.right").font(.system(size:30))
                                    }
                                
                            }.padding(.horizontal).padding(.vertical,5).foregroundColor(.black)
                            
                            HStack {
                                if selection == .normal{
                                    Button(action: {
                                        vm.deleteRecording(folderPath: folder.path, url: vm.recordingsList[idx].fileURL)
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
                                    Text("actions").font(.body)
                                }
                                
                                if selection == .summary {
                                    Text("summary").font(.body)
                                }
                            }.foregroundColor(.black).padding(.horizontal)
                        }.padding(.horizontal,10).padding(.vertical, 10).frame(width: 350)
                            .background(Color.white)
                            .cornerRadius(5)
                            
                    }
                }.padding(.vertical, 10)
                
                Image(systemName: vm.isRecording ? "stop.circle.fill" : "mic.circle")
                    .foregroundColor(.red)
                    .font(.system(size: 50))
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
}
