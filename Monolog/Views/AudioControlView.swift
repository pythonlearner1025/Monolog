//
//  AudioPlayerControlView.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import SwiftUI

struct AudioControlView: View {
    @ObservedObject var audioPlayer: AudioPlayerModel
    @Binding var playingRecordingPath: String
    
    init(_ audioPlayer: AudioPlayerModel, playingRecordingPath: Binding<String>){
        print("RERENDER")
        self.audioPlayer = audioPlayer
        _playingRecordingPath = playingRecordingPath
    }
    
    var body: some View {
        Group {
            HStack {
                Text(audioPlayer.currentTime)
                    .font(.caption.monospacedDigit())
                Slider(value: $audioPlayer.audioPlayer.currentTime, in: 0...audioPlayer.audioPlayer.duration).accentColor(Color.primary)
            }
            .padding()
            HStack{
                Spacer()
                Button(action: {
                    if audioPlayer.isPlaying == true {
                        audioPlayer.stopPlaying()
                    }else{
                        audioPlayer.startPlaying()
                        playingRecordingPath = audioPlayer.audioPath
                    }}) {
                        Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                            .font(.title)
                            .imageScale(.large)
                            .foregroundColor(.primary)
                    }.buttonStyle(.borderless)
                Spacer()
            }
        }.onChange(of: playingRecordingPath, perform: { path in
            print("new recording playing at \(path)")
            if audioPlayer.isPlaying && audioPlayer.audioPath != path {
                print("stopping this recording \(audioPlayer.audioPath)")
                audioPlayer.stopPlaying()
            }
        })
    }
    private let formatter: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "EEEE, MMMM d, yyyy"
         return formatter
     }()
}