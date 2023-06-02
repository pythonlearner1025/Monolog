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


class VoiceViewModel : NSObject, ObservableObject , AVAudioPlayerDelegate{
    var audioRecorder : AVAudioRecorder!
    @Published var audioPlayer : AVAudioPlayer!
    @Published var audioPlayerEnabled : Bool = false
    var indexOfPlayer = 0
    private var cancellables = Set<AnyCancellable>()
    let baseURL = "http://0.0.0.0:3000/api/v1/"
    let folderPath: String

    @Published var isRecording : Bool = false
    @Published var recordingsList: [ObservableRecording] = []
    @Published var countSec = 0
    @Published var timerCount : Timer?
    @Published var blinkingCount : Timer?
    @Published var timer : String = "0:00"
    @Published var toggleColor : Bool = false
    var formatter : DateComponentsFormatter
        
    init(folderPath: String){
        self.formatter = DateComponentsFormatter()
        self.formatter.allowedUnits = [.minute, .second]
        self.formatter.unitsStyle = .positional
        self.formatter.zeroFormattingBehavior = [ .pad ]
        self.folderPath = folderPath
        super.init()
        fetchAllRecording()
    }
    
    func startRecording() {
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
        
        //print("Beginning recording")
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            print("Cannot setup the Recording")
        }
        
        let filePath = rawFolderURL.appendingPathComponent("Recording: \(Date().toString(dateFormat: "dd-MM-YY 'at' HH:mm:ss")).m4a")
        //print("Recording will be saved at: \(fileName)")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: filePath, settings: settings)
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

    func stopRecording(){
        //print("stopped recording")
        audioRecorder.stop()
        isRecording = false
        timerCount!.invalidate()
        blinkingCount!.invalidate()
        
        // write Recordings to localStorage as well.
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: folderPath)
        let fileURL = audioRecorder.url
        print("-- saving at this loc --")
        print(fileURL)
        do{audioPlayer = try AVAudioPlayer(contentsOf: fileURL)}
        catch {print("recording error")}
        var recording = ObservableRecording(filePath: fileURL.lastPathComponent, createdAt: getFileDate(for: fileURL), isPlaying: false, title: "Untitled", outputs: [], totalTime: self.formatter.string(from: TimeInterval(self.audioPlayer.duration))!, duration: self.audioPlayer.duration)
        self.countSec = 0
        recordingsList.insert(recording, at: 0)

        let recordingMetadataURL = folderURL.appendingPathComponent("\(fileURL.lastPathComponent).json")
           let encoder = JSONEncoder()
           encoder.dateEncodingStrategy = .iso8601 // to properly encode the Date field
           do {
               let data = try encoder.encode(recording)
               try data.write(to: recordingMetadataURL)
           } catch {
               print("An error occurred while saving the recording object: \(error)")
           }
        
        generateTranscription(recording: recording).sink(receiveCompletion: { [self] (completion) in
            switch completion {
            case .failure(let error):
                print("An error occurred while generating transcript: \(error)")
                if let settings = UserDefaults.standard.settings(forKey: "Settings") {
                    self.addErrorOutput(type: .Transcript, content: "Error, tap to retry", settings: OutputSettings.defaultSettings, outputs: &recording.outputs)
                }
                do {
                    print("-- saving transcript error data --")
                    print(recording)
                    let updatedData = try encoder.encode(recording)
                    try updatedData.write(to: recordingMetadataURL)
                } catch {
                    print("Error saving generate-transcript-error to recording: \(error)")
                }
            case .finished:
                break
            }
        }, receiveValue: { update in
            print("* update: Transcript **")
            self.addOutput(type: .Transcript, content: update.content, settings: update.settings, outputs: &recording.outputs)
            do {
                let updatedData = try encoder.encode(recording)
                try updatedData.write(to: recordingMetadataURL)
            } catch {
                print("An error occurred while updating the recording object: \(error)")
            }
            if let settings = UserDefaults.standard.settings(forKey: "Settings") {
                let outputSettings = OutputSettings(length: settings.length, format: settings.format, style: settings.style, prompt: "", name: "Default Output")
                print("== all settings outputs \(settings.outputs)==")
                var futures = settings.outputs.map { outputType -> AnyPublisher<Update, OutputGenerationError> in
                    self.generateOutput(transcript: recording.outputs[0].content, outputType: outputType, outputSettings: outputSettings)
                       .eraseToAnyPublisher()
               }
                
                Publishers.Sequence(sequence: futures)
                    .flatMap { future in
                        future.catch { error -> AnyPublisher<Update, Never> in
                            switch error {
                            case .failure(let error, let outputType, let transcript):
                                switch outputType {
                                    case .Summary:
                                    self.addErrorOutput(type: .Summary, content: "Error, tap to retry", settings: outputSettings, outputs: &recording.outputs)
                                        break
                                    case .Action:
                                    self.addErrorOutput(type: .Action, content:  "Error, tap to retry", settings: outputSettings, outputs: &recording.outputs)
                                        break
                                    case .Title:
                                        self.addErrorOutput(type: .Title, content:  "Error, tap to retry", settings: outputSettings, outputs: &recording.outputs)
                                        break
                                    case .Transcript:
                                        break
                                    case .Custom:
                                        self.addErrorOutput(type: .Custom, content:  "Error, tap to retry", settings: outputSettings, outputs: &recording.outputs)
                                        break
                                }
                                do {
                                    print("-- saving output error data --")
                                    print(recording.outputs)
                                    let updatedData = try encoder.encode(recording)
                                    try updatedData.write(to: recordingMetadataURL)
                                    self.refreshRecording(recording: recording)
                                }
                                catch {
                                    print("Error saving output-generate-error to recording: \(error)")
                                }
                                // replace the error with an alternative output
                                //return Just(Update(type: outputType, content: "", settings: outputSettings)).eraseToAnyPublisher()
                                return Empty(completeImmediately: true).eraseToAnyPublisher()

                            }
                    
                        }
                    }
                    .sink(receiveCompletion: { _ in }, receiveValue: { update in
                        // update entire recording whether it be title, or output stream.
                        
                        // TODO: for some reason, receiveValue is being called when update.content == "". If
                        // update.content == "", treat as failure and don't add output.
                        switch update.type {
                            case .Summary:
                                print("** update: summary **")
                                self.addOutput(type: .Summary, content: update.content, settings: update.settings, outputs: &recording.outputs)
                               
                                break
                            case .Action:
                                print("** update: action **")
                                self.addOutput(type: .Action, content: update.content, settings: update.settings, outputs: &recording.outputs)
                              
                                break
                            case .Title:
                                print("** update: Title **")
                                recording.title = update.content
                                self.addOutput(type: .Title, content: update.content, settings: update.settings, outputs: &recording.outputs)
                                break
                            case .Transcript:
                                break
                            case .Custom:
                                print("** update: Custom **")

                                recording.title = update.content
                                self.addOutput(type: .Custom, content: update.content, settings: update.settings, outputs: &recording.outputs)
                                
                                break
                        }
                        do {
                            let updatedData = try encoder.encode(recording)
                            try updatedData.write(to: recordingMetadataURL)
                            print("** after update **")
                            self.refreshRecording(recording: recording)
                        }
                        catch {
                            print("An error occurred while saving the recording object: \(error)")
                        }
                    })
                   .store(in: &self.cancellables)
            }

        }).store(in: &cancellables) // make sure `cancellables` is a property of the class so the subscription does not get deallocated
    }
    
    // TODO: add updateOutput function to be called when user re-generates output
    
    
    func addOutput(type: OutputType, content: String, settings: OutputSettings, outputs: inout [Output]) {
        if let index = outputs.firstIndex(where: { $0.type == type }) {
            outputs[index].content = content
        } else {
            let newOutput = Output(type: type, content: content, settings: settings)
            outputs.append(newOutput)
        }
    }
    
    func updateOutput(type: OutputType, content: String,  settings: OutputSettings, outputs: inout [Output]) {
        if let index = outputs.firstIndex(where: { $0.type == type }) {
            outputs[index].content = content
            outputs[index].settings = settings
            outputs[index].error = false
        }
    }
    
    func addErrorOutput(type: OutputType, content: String, settings: OutputSettings, outputs: inout [Output]) {
        if let index = outputs.firstIndex(where: { $0.type == type }) {
            outputs[index].content = content
        } else {
            let newOutput = Output(type: type, content: content, settings: settings)
            newOutput.error = true
            outputs.append(newOutput)
        }
    }
    
    func getTranscript(outputs: [Output]) -> String {
        if let index = outputs.firstIndex(where: {$0.type == .Transcript}) {
            return outputs[index].content
        } else {
            return ""
        }
    }
    
    func regenerateTranscript(index: Int) {
        //TODO: regenerate transcript
    }
    
    func regenerateOutput(index: Int, output: Output, outputSettings: OutputSettings) {
        var recording = recordingsList[index]
        let transcript = getTranscript(outputs: recording.outputs)
        let recordingMetadataURL = getRecordingMetaURL(filePath: recording.filePath)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601 // to properly encode the Date field
        generateOutput(transcript: transcript, outputType: output.type, outputSettings: outputSettings).sink(
            receiveCompletion: { completion in
                switch (completion) {
                case .failure(let error):
                    print("failed to regenerate \(error)")
                case .finished:
                    break
                }
            },
            receiveValue:{ update in
                self.updateOutput(type: output.type, content: update.content, settings: outputSettings, outputs: &recording.outputs)
                do {
                    let updatedData = try encoder.encode(recording)
                    try updatedData.write(to: recordingMetadataURL)
                    print("** recording after regenerated output **")
                    print(recording)
                    self.recordingsList[index] = recording
                } catch {
                    print("error saving updated output")
                }
            })
            .store(in: &self.cancellables)
    }
    
    func generateCustomOutput(index: Int, outputSettings: OutputSettings) {
        var recording = recordingsList[index]
        let transcript = getTranscript(outputs: recording.outputs)
        let recordingMetadataURL = getRecordingMetaURL(filePath: recording.filePath)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601 // to properly encode the Date field
        generateOutput(transcript: transcript, outputType: .Custom, outputSettings: outputSettings).sink(
            receiveCompletion: { completion in
                switch (completion) {
                    case .failure(let error):
                        self.addErrorOutput(type: .Custom, content: "Error, tap to retry", settings: outputSettings, outputs: &recording.outputs)
                        do {
                            print("-- saving custom output error data --")
                            let updatedData = try encoder.encode(recording)
                            try updatedData.write(to: recordingMetadataURL)
                            self.recordingsList[index] = recording
                        }
                        catch {
                            print("Error saving output-generate-error to recording: \(error)")
                        }
                        break
                    case .finished:
                        break
                   
                }
            },
            receiveValue:{ update in
                self.addOutput(type: .Custom, content: update.content, settings: outputSettings, outputs: &recording.outputs)
                do {
                    let updatedData = try encoder.encode(recording)
                    try updatedData.write(to: recordingMetadataURL)
                    print("** recording after regenerated output **")
                    print(recording)
                    self.recordingsList[index] = recording
                } catch {
                    print("error saving updated output")
                }
            })
    }
    
    func generateOutput(transcript: String, outputType: OutputType, outputSettings: OutputSettings) -> Future<Update, OutputGenerationError> {
        return Future { promise in
            print("== Generating for \(outputType.rawValue) ==")
            let url = self.baseURL + "generate_output"
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601 // to properly encode the Date field
            
            do {
                let encodedSettings = try encoder.encode(outputSettings)
                let settingsDictionary = try JSONSerialization.jsonObject(with: encodedSettings, options: .allowFragments) as? [String: Any]
                let parameters: [String: Any] = [
                    "type": outputType.rawValue,
                    "transcript": transcript,
                    "settings": settingsDictionary ?? [:]
                ]
                
                AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                    .validate()
                    .responseJSON { response in
                        switch response.result {
                        case .success(let value):
                            if let JSON = value as? [String: Any] {
                                let output = JSON["out"] as? String ?? ""
                                let update = Update(type: outputType, content: output, settings: outputSettings)
                                promise(.success(update))
                            }
                        case .failure(let error):
                            print(error)
                            promise(.failure(OutputGenerationError.failure(error: error, outputType: outputType, transcript: transcript)))
                        }
                }

            } catch {
                print(error)
            }
        }
    }

    func generateTranscription(recording: ObservableRecording) -> Future<Update, Error> {
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
            data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(recording.filePath)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)

            do {
                let fileData = try Data(contentsOf: self.getFileURL(filePath: recording.filePath))
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
                    DispatchQueue.main.async {
                        if let transcript = response["transcript"] {
                            let update = Update(type: .Transcript, content: transcript, settings: OutputSettings.defaultSettings)
                            promise(.success(update))
                        } else {
                            promise(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                        }
                    }

                } catch {
                    print("Decoding error: \(error)")
                    promise(.failure(error))
                }
            }.resume()
        }
    }
    
    func refreshRecording(recording: ObservableRecording) {
        let filePath = recording.filePath
        if let index = recordingsList.firstIndex(where: { $0.filePath == filePath }) {
            recordingsList[index] = recording
        }
    }

    func fetchAllRecording(){
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

    // TODO: major changes to start / stop playing
    func startPlaying(index: Int, filePath: String) {
        print("start playing")
        
        
        let url = getFileURL(filePath: filePath)
        let playSession = AVAudioSession.sharedInstance()
        
        do {
            try playSession.setCategory(.playback, mode: .default, options: .defaultToSpeaker)
        } catch {
            print("Playing failed in Device")
        }
        
        
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                print("File exists")
            } else {
                print("File not found")
            }
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayerEnabled = true
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            audioPlayer.play()
        } catch {
            print("Audioplayer failed: \(error)")
        }

  
        let updatedRecording = recordingsList[index]
        updatedRecording.isPlaying = true
        recordingsList[index] = updatedRecording
        print(self.formatter
            .string(from:
                   TimeInterval(audioPlayer.duration))!)
        print(self.formatter
            .string(from:
                        TimeInterval(self.audioPlayer.duration))!)
        
        // TODO: glitch in play forward by 15 seconds.
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true){ _ in
            if(self.recordingsList[index].isPlaying){
                let updatedRecording = self.recordingsList[index]
                
                updatedRecording.currentTime = self.formatter.string(from: TimeInterval(self.audioPlayer.currentTime))!
                print(updatedRecording.currentTime)
                updatedRecording.progress = CGFloat(self.audioPlayer.currentTime / self.audioPlayer.duration)
                self.recordingsList[index] = updatedRecording
                self.objectWillChange.send()
            }
            if (!self.recordingsList[index].isPlaying && self.recordingsList[index].totalTime == self.recordingsList[index].currentTime) {
                self.recordingsList[index].progress = 0
                self.recordingsList[index].currentTime = self.formatter.string(from: TimeInterval(0.0))!
            }
            self.objectWillChange.send()
             
        }
    }
    
    func stopPlaying(index: Int) {
        print("stopping playing")
        let updatedRecording = recordingsList[index]
        updatedRecording.isPlaying = false
        recordingsList[index] = updatedRecording
        audioPlayer.stop()
    }
    
    func forward15(index: Int, filePath : String) {
        startPlaying(index: index, filePath: filePath)
        if(audioPlayerEnabled){
            let increase = audioPlayer.currentTime + 15
            if increase < audioPlayer.duration {
                audioPlayer.currentTime = increase
            } else {
                let updatedRecording = recordingsList[index]
                audioPlayer.currentTime = audioPlayer.duration
            }
            self.objectWillChange.send()
            //stopPlaying(index: index, url: url)
        }
        else{
            print("error: audio player not enabled")
        }
    }
    
    func backwards15(index: Int, filePath : String) {
        startPlaying(index: index, filePath: filePath)
        if(audioPlayerEnabled){
            let decrease = audioPlayer.currentTime - 15
            if decrease > 0 {
                audioPlayer.currentTime = decrease
            } else {
                audioPlayer.currentTime = 0
            }
            self.objectWillChange.send()
            //stopPlaying(index: index, url: url)
        }
        else{
            print("error: audio player not enabled")
        }
    }
            
    
    func seekTo(time: TimeInterval){
        self.audioPlayer.currentTime = time
    }
    
 
    func deleteRecording(recordingURL: URL, filePath: String) {
        do {
            try FileManager.default.removeItem(at: recordingURL)
        } catch {
            print("Can't delete")
        }
        
        for i in 0..<recordingsList.count {
            
            if recordingsList[i].filePath == filePath {
                if recordingsList[i].isPlaying == true{
                    stopPlaying(index: i)
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
    
    func getFileURL(filePath: String) -> URL {
        var rawFolderURL = URL(fileURLWithPath: folderPath).appendingPathComponent("raw")
        rawFolderURL.append(path: filePath)
        return rawFolderURL
    }
    
    func getRecordingMetaURL(filePath: String) -> URL {
        let folderURL = URL(fileURLWithPath: folderPath)
        let recordingMetadataURL = folderURL.appendingPathComponent("\(filePath).json")
        return recordingMetadataURL
    }
}
