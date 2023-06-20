//
//  AudioPlayerModel.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import Foundation
import AVFoundation

class AudioPlayerModel : NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var audioPlayer : AVAudioPlayer!
    @Published var isPlaying : Bool = false
    @Published var progress: CGFloat = 0.0
    @Published var absProgress: Double = 0.0
    @Published var currentTime: String = "00:00"
    let audioPath: String
    var indexOfPlayer = 0
    var formatter : DateComponentsFormatter
    var timer: Timer? // Add this
    var id = UUID()
        
    init(folderPath: String, audioPath: String){
        self.formatter = DateComponentsFormatter()
        self.formatter.allowedUnits = [.minute, .second]
        self.formatter.unitsStyle = .positional
        self.formatter.zeroFormattingBehavior = [ .pad ]
        self.audioPath = audioPath
        do {
            let folderURL = Util.buildFolderURL(folderPath)
            let rawURL = folderURL.appendingPathComponent("raw", isDirectory: true)
            let audioURL = rawURL.appendingPathComponent(audioPath)
            self.audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
        } catch {
            print("audioPlayerModel \(error)")
        }
    }
    
    func reinit(folderPath: String, audioPath: String) {
        do {
            let folderURL = Util.buildFolderURL(folderPath)
            let rawURL = folderURL.appendingPathComponent("raw", isDirectory: true)
            let audioURL = rawURL.appendingPathComponent(audioPath)
            self.audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
        } catch {
            print("audioPlayerModel \(error)")
        }
    }

    func startPlaying() {
        let playSession = AVAudioSession.sharedInstance()
        do {
            try playSession.setCategory(.playback, mode: .default, options: .defaultToSpeaker)
        } catch {
            print("Playing failed in Device")
        }
        
        do {
            if(isPlaying){
                stopPlaying()
            }
            isPlaying = true
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            audioPlayer.currentTime = absProgress
            audioPlayer.play()
            timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.isPlaying {
                    self.currentTime = self.formatter.string(from: TimeInterval(self.audioPlayer.currentTime))!
                    self.progress = CGFloat(self.audioPlayer.currentTime / self.audioPlayer.duration)
                    self.absProgress = self.audioPlayer.currentTime
                    if !self.audioPlayer.isPlaying {
                        self.stopPlaying()
                        self.timer?.invalidate() // Terminate timer
                    }
                    self.objectWillChange.send()
                }
            }
            
        } catch {
            print("Audioplayer failed: \(error)")
        }

    }
    
    func stopPlaying() {
        if(isPlaying){
            audioPlayer.stop()
            isPlaying = false
        }
    }
    
    func forward15(index: Int, filePath : String) {
        if(isPlaying){
            let increase = audioPlayer.currentTime + 15
            if increase < audioPlayer.duration {
                audioPlayer.currentTime = increase
            } else {
                stopPlaying()
                audioPlayer.currentTime = 0
            }
            
            currentTime = self.formatter.string(from: TimeInterval(self.audioPlayer.currentTime))!
            progress = CGFloat(self.audioPlayer.currentTime / self.audioPlayer.duration)
            absProgress = self.audioPlayer.currentTime
            isPlaying = audioPlayer.isPlaying
        }
        else{
            print("error: audio player not enabled")
        }
    }
    
    func backwards15(index: Int, filePath : String) {
        if(isPlaying){
            let decrease = audioPlayer.currentTime - 15
            if decrease > 0 {
                audioPlayer.currentTime = decrease
            } else {
                audioPlayer.currentTime = 0
            }
            
            currentTime = self.formatter.string(from: TimeInterval(self.audioPlayer.currentTime))!
            progress = CGFloat(self.audioPlayer.currentTime / self.audioPlayer.duration)
            absProgress = self.audioPlayer.currentTime
        }
        else{
            print("error: audio player not enabled")
        }
    }
    
    func seekTo(time: TimeInterval, index: Int){
        self.audioPlayer.currentTime = time
    }
    
}

