//
//  VoiceModel.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//

import Foundation
import AVFoundation
import Combine
import Alamofire

/*
 backend pseudocode
 
 - have a constant of default outputs:
    * summary
    * actions
    * TBD
 
 - show loading screen until transcript is generated
 - once transcript is generated, begin streaming generation of outputs,
    in parallel. Sync the JSON blob per every character streamed
 */


class VoiceViewModel : NSObject, ObservableObject , AVAudioPlayerDelegate{
    var audioRecorder : AVAudioRecorder!
    @Published var audioPlayer : AVAudioPlayer!
    var indexOfPlayer = 0
    private var cancellables = Set<AnyCancellable>()
    let baseURL = "http://0.0.0.0:3000/api/v1/"


    @Published var isRecording : Bool = false
    @Published var recordingsList: [ObservableRecording] = []
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

    //TODO: realtime update of recordingList...
    func stopRecording(folderPath: String){
        print("stopped recording")
        audioRecorder.stop()
        
        isRecording = false
        
        
        
        timerCount!.invalidate()
        blinkingCount!.invalidate()
        
        // write Recordings to localStorage as well.
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folderPath)
        let fileURL = audioRecorder.url
        do{audioPlayer = try AVAudioPlayer(contentsOf: fileURL)}
        catch {print("error")}
        var recording = ObservableRecording(fileURL: fileURL, createdAt: getFileDate(for: fileURL), isPlaying: false, title: "Untitled", outputs: [], totalTime: audioPlayer.duration)
        self.countSec = 0
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
        
        generateTranscription(recording: recording).sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let error):
                print("An error occurred while generating transcript: \(error)")
            case .finished:
                break
            }
        }, receiveValue: { updatedRecording in
            do {
                print("*transcript generated*")
                print(updatedRecording)
                recording = updatedRecording
                let updatedData = try encoder.encode(recording)
                try updatedData.write(to: recordingMetadataURL)
                if let settings = UserDefaults.standard.settings(forKey: "Settings") {
                    var futures = settings.outputs.map { outputType -> AnyPublisher<Update, Error> in
                       self.generateOutput(transcript: recording.outputs[0].content, outputType: outputType, settings: settings)
                           .eraseToAnyPublisher()
                   }
                    
                    Publishers.Sequence(sequence: futures)
                        .flatMap { $0 }
                        .sink(receiveCompletion: self.handleReceiveCompletion, receiveValue: {update in
                            // update entire recording whether it be title, or output stream.
                            do {
                                switch update.type {
                                    case .Summary:
                                        print("** update: summary **")
                                        print(update)
                                        self.updateOutput(type: .Summary, content: update.content, outputs: &recording.outputs)
                                        break
                                    case .Action:
                                        print("** update: action **")
                                        print(update)
                                        self.updateOutput(type: .Action, content: update.content, outputs: &recording.outputs)
                                        break
                                    case .Title:
                                        print("** update: Title **")
                                        print(update)
                                        recording.title = update.content
                                        self.updateOutput(type: .Title, content: update.content, outputs: &recording.outputs)
                                    case .Transcript:
                                        print("** skipping transcript **")
                                }
                                let updatedData = try encoder.encode(recording)
                                try updatedData.write(to: recordingMetadataURL)
                                print("** after update **")
                                print(recording)
                                self.refreshRecording(fileURL: fileURL, recording: recording)
                                
                            }
                            catch {
                                print("An error occurred while updating the recording object: \(error)")
                            }
                        })
                       .store(in: &self.cancellables)
                }
                
            } catch {
                print("An error occurred while updating the recording object: \(error)")
            }
        }).store(in: &cancellables) // make sure `cancellables` is a property of the class so the subscription does not get deallocated
    }
    
    func updateOutput(type: OutputType, content: String, outputs: inout [Output]) {
        if let index = outputs.firstIndex(where: { $0.type == type }) {
            outputs[index].content = content
        } else {
            let newOutput = Output(type: type, content: content)
            outputs.append(newOutput)
        }
    }

    func handleReceiveCompletion(completion: Subscribers.Completion<Error>) {
        switch completion {
           case .failure(let error):
               print("An error occurred while generating transcript: \(error)")
           case .finished:
               break
           }
    }
    
    
    func generateOutput(transcript: String, outputType: OutputType, settings: Settings) -> Future<Update, Error> {
        return Future { promise in
            let url = self.baseURL + "generate_output"
            print("ATTENTION HERE")
            print(outputType.rawValue)
            let parameters: [String: Any] = [
                "type": outputType.rawValue,
                "transcript": transcript
            ]
            
            AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .responseJSON { response in
                    switch response.result {
                    case .success(let value):
                        if let JSON = value as? [String: Any] {
                            let output = JSON["out"] as? String ?? ""
                            let update = Update(type: outputType, content: output)
                            promise(.success(update))
                        }
                    case .failure(let error):
                        promise(.failure(error))
                    }
            }
        }
    }
    

    func generateTranscription(recording: ObservableRecording) -> Future<ObservableRecording, Error> {
        return Future { promise in
            let url = URL(string: self.baseURL + "transcribe")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer 046cc07d8daab73e53e9089dda05acf4750e1a3cd23c87bff0cbafd0975a949b", forHTTPHeaderField: "Authorization")

            // Set the content type to be multipart/form-data
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var data = Data()
            data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(recording.fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)

            do {
                let fileData = try Data(contentsOf: recording.fileURL)
                data.append(fileData)
            } catch {
                print("Failed to read file data: \(error)")
                promise(.failure(error))
                return
            }

            data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            // Set the HTTPBody with the form data we created
            request.httpBody = data

            URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let data = data, error == nil else {
                    print("Error: \(error?.localizedDescription ?? "Unknown error")")
                    promise(.failure(error!))
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode([String: String].self, from: data)
                    if let transcript = response["transcript"] {
                        let updatedRecording = recording
                        let output: Output = Output(type: .Transcript, content: transcript)
                        updatedRecording.outputs = [output]
                        promise(.success(updatedRecording))
                    } else {
                        promise(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                    }
                } catch {
                    print("Decoding error: \(error)")
                    promise(.failure(error))
                }
            }.resume()
        }
    }
    
    func refreshRecording(fileURL: URL, recording: ObservableRecording) {
        if let index = recordingsList.firstIndex(where: { $0.fileURL == fileURL }) {
            recordingsList[index] = recording
        }
    }

    func fetchAllRecording(folderPath: String){
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folderPath)
        let directoryContents = try! fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // match the encoding strategy

        for i in directoryContents {
            if (i.lastPathComponent == "raw") {
                continue
            }
            else {
                let jsonURL = folderURL.appendingPathComponent("\(i.lastPathComponent)")
                do {
                    let data = try Data(contentsOf: jsonURL)
                    let recording = try decoder.decode(ObservableRecording.self, from: data)
                    recordingsList.append(recording)
                } catch {
                    print("An error occurred while decoding the recording object: \(error)")
                }
            }
        }

        recordingsList.sort(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending})
    }

    func startPlaying(url : URL) {
        print("start playing")
        print(url)
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
                    print("setting to true")
                    let updatedRecording = recordingsList[i]
                    updatedRecording.isPlaying = true
                    recordingsList[i] = updatedRecording
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
                let updatedRecording = recordingsList[i]
                updatedRecording.isPlaying = false
                recordingsList[i] = updatedRecording
            }
        }
    }
    
    func seekTo(time: TimeInterval){
        self.audioPlayer.currentTime = time
    }
    
 
    func deleteRecording(folderPath: String, url : URL) {
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folderPath)
        let recordingMetadataURL = folderURL.appendingPathComponent("\(url.lastPathComponent).json")
        do {
            try FileManager.default.removeItem(at: recordingMetadataURL)
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
