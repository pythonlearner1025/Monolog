//
//  VoiceModel.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//

import Foundation
import AVFoundation

struct Recording: Encodable {
    var fileURL: URL
    var createdAt: Date
    var isPlaying: Bool
    var title: String // title of the recording, generated asynchronously
    var outputs: [Output] // list of outputs, generated asynchronously
}

struct Output: Encodable {
    var type: OutputType
    var content: String
}

enum OutputType: String, Encodable {
    case Transcript
    case Summary
    case TODO
}

extension Recording {
    func generateOutputs() {
        // This function will be responsible for generating the title and outputs for the recording asynchronously
        // Once an output is generated, it will be added to the 'outputs' array
        // You will need to fill in the implementation details based on your specific use case and APIs you are using
    }
}

class VoiceViewModel : NSObject, ObservableObject , AVAudioPlayerDelegate{
    var audioRecorder : AVAudioRecorder!
    var audioPlayer : AVAudioPlayer!
    var indexOfPlayer = 0
    
    @Published var isRecording : Bool = false
    @Published var recordingsList = [Recording]()
    @Published var countSec = 0
    @Published var timerCount : Timer?
    @Published var blinkingCount : Timer?
    @Published var timer : String = "0:00"
    @Published var toggleColor : Bool = false
    
    
    var playingURL : URL?
    
    init(folderPath: String){
        super.init()
        fetchAllRecording(folderPath: folderPath)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
       
        for i in 0..<recordingsList.count {
            if recordingsList[i].fileURL == playingURL {
                recordingsList[i].isPlaying = false
            }
        }
    }
    
  
    
    func startRecording(folderPath: String) {
        let fileManager = FileManager.default
        let rawFolderURL = URL(fileURLWithPath: folderPath).appendingPathComponent("raw")
        
        // Create the raw folder if it doesn't exist
        if !fileManager.fileExists(atPath: rawFolderURL.path) {
            do {
                try fileManager.createDirectory(at: rawFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("An error occurred while creating the raw folder: \(error)")
                return
            }
        }
        
        print("Beginning recording")
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            print("Cannot setup the Recording")
        }
        
        let fileName = rawFolderURL.appendingPathComponent("Recording: \(Date().toString(dateFormat: "dd-MM-YY 'at' HH:mm:ss")).m4a")
        print("Recording will be saved at: \(fileName)")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileName, settings: settings)
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            isRecording = true
            
            timerCount = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (value) in
                self.countSec += 1
                self.timer = self.covertSecToMinAndHour(seconds: self.countSec)
            })
            blinkColor()
            
        } catch {
            print("Failed to Setup the Recording")
        }
    }

    
    
    func stopRecording(folderPath: String){
        print("stopped recording")
        audioRecorder.stop()
        
        isRecording = false
        
        self.countSec = 0
        
        timerCount!.invalidate()
        blinkingCount!.invalidate()
        
        // write Recordings to localStorage as well.
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folderPath)
        let fileURL = audioRecorder.url
        let recording = Recording(fileURL: fileURL, createdAt: getFileDate(for: fileURL), isPlaying: false, title: "Untitled", outputs: [])
        recordingsList.insert(recording, at: 0)
        print("recording struct to be saved:")
        print(recording)
        let recordingMetadataURL = folderURL.appendingPathComponent("\(fileURL.lastPathComponent).json")
           let encoder = JSONEncoder()
           encoder.dateEncodingStrategy = .iso8601 // to properly encode the Date field
           do {
               let data = try encoder.encode(recording)
               try data.write(to: recordingMetadataURL)
           } catch {
               print("An error occurred while saving the recording object: \(error)")
           }
        
        // TODO: generate Title, generate Outputs and modify saved Recording.
        /*
            - first generate transcript from audio using Whisper API
            - then, generate title
            - generate two other outputs separately
         
            Have loading toggle on/off for each. 
         */
    }
    
   
    

    func fetchAllRecording(folderPath: String){
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folderPath)
        let directoryContents = try! fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)

        for i in directoryContents {
            print(i)
            if (i.lastPathComponent == "raw") {
                print("Skip raw folder")
            }
            else {
                recordingsList.append(Recording(fileURL: i, createdAt: getFileDate(for: i), isPlaying: false, title: "Untitled", outputs: []))
            }
        }
        
        recordingsList.sort(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending})
    }
    
    
    func startPlaying(url : URL) {
        print("start playing")
        playingURL = url
        
        let playSession = AVAudioSession.sharedInstance()
        
        do {
            try playSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        } catch {
            print("Playing failed in Device")
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            
            for i in 0..<recordingsList.count {
                if recordingsList[i].fileURL == url {
                    recordingsList[i].isPlaying = true
                }
            }
            
        } catch {
            print("Playing Failed")
        }
        
        
    }
    
    func stopPlaying(url : URL) {
        print("stopping playing")
        audioPlayer.stop()
        
        for i in 0..<recordingsList.count {
            if recordingsList[i].fileURL == url {
                recordingsList[i].isPlaying = false
            }
        }
    }
    
 
    func deleteRecording(url : URL) {
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Can't delete")
        }
        
        for i in 0..<recordingsList.count {
            
            if recordingsList[i].fileURL == url {
                if recordingsList[i].isPlaying == true{
                    stopPlaying(url: recordingsList[i].fileURL)
                }
                recordingsList.remove(at: i)
                
                break
            }
        }
    }
    
    func blinkColor() {
        
        blinkingCount = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: { (value) in
            self.toggleColor.toggle()
        })
        
    }
    
    
    func getFileDate(for file: URL) -> Date {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path) as [FileAttributeKey: Any],
            let creationDate = attributes[FileAttributeKey.creationDate] as? Date {
            return creationDate
        } else {
            return Date()
        }
    }
    
    
    
}
