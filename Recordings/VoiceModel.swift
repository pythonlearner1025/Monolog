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
    var audioPlayerCurrentURL : URL!
    var audioPlayerCurrentIndex : Int!
    var indexOfPlayer = 0
    private var cancellables = Set<AnyCancellable>()
    let baseURL = "https://turing-api.com/api/v1/"
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
        let fileURL = audioRecorder.url
        do{audioPlayer = try AVAudioPlayer(contentsOf: fileURL)}
        catch {print("recording error")}
        let recording = ObservableRecording(filePath: fileURL.lastPathComponent, createdAt: getFileDate(for: fileURL), isPlaying: false, title: "Untitled", outputs: Outputs(), totalTime: self.formatter.string(from: TimeInterval(self.audioPlayer.duration))!, duration: self.audioPlayer.duration)
        self.countSec = 0
        recordingsList.insert(recording, at: 0)
        generateAll(recording: recording, fileURL: fileURL)
    }
    
    func saveImportedRecording(filePath: URL){
        let fileManager = FileManager.default
        let rawFolderURL = URL(fileURLWithPath: folderPath).appendingPathComponent("raw")
        let date = Date()
        let newFileURL = rawFolderURL.appendingPathComponent("Recording: \(date.toString(dateFormat: "dd-MM-YY 'at' HH:mm:ss")).m4a")
        do {
            try fileManager.copyItem(at: filePath, to: newFileURL)
        } catch {
            print("An error occurred while copying the file: \(error)")
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: newFileURL)
        } catch {
            print("recording read error \(error)")
        }
        let recording = ObservableRecording(filePath: newFileURL.lastPathComponent, createdAt: date, isPlaying: false, title: "Untitled", outputs: Outputs(), totalTime: self.formatter.string(from: TimeInterval(self.audioPlayer.duration))!, duration: self.audioPlayer.duration)
        self.countSec = 0
        recordingsList.insert(recording, at: 0)
        generateAll(recording: recording, fileURL: newFileURL)
    }
    
    func generateAll(recording: ObservableRecording, fileURL: URL) {
        let folderURL = URL(fileURLWithPath: folderPath)
        let recordingMetadataURL = folderURL.appendingPathComponent("\(fileURL.lastPathComponent).json")
           let encoder = JSONEncoder()
           encoder.dateEncodingStrategy = .iso8601 // to properly encode the Date field
           do {
               let data = try encoder.encode(recording)
               try data.write(to: recordingMetadataURL)
           } catch {
               print("An error occurred while saving the recording object: \(error)")
           }
        var transcript_out = Output(type: .Transcript, content: "Loading", settings: OutputSettings.defaultSettings)
        if !recording.outputs.outputs.contains(where: {$0.type == .Transcript}) {
            recording.outputs.outputs.append(transcript_out)
        } else {
            transcript_out = recording.outputs.outputs.first(where: {$0.type == .Transcript})!
        }
        //refreshRecording(recording: recording)
        generateTranscription(recording: recording).sink(receiveCompletion: { [self] (completion) in
            switch completion {
            case .failure(let error):
                print("An error occurred while generating transcript: \(error)")
                self.updateErrorOutput(transcript_out.id.uuidString, settings: OutputSettings.defaultSettings, outputs: &recording.outputs.outputs)
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
            self.updateOutput(transcript_out.id.uuidString, content: update.content, settings: update.settings, outputs: &recording.outputs.outputs)
            do {
                let updatedData = try encoder.encode(recording)
                try updatedData.write(to: recordingMetadataURL)
            } catch {
                print("An error occurred while updating the recording object: \(error)")
            }
            if let settings = UserDefaults.standard.getSettings(forKey: "Settings") {
                let outputSettings = OutputSettings(length: settings.length, format: settings.format, tone: settings.tone,  name: "Default Output", prompt: "")
                print("== all settings outputs \(settings.outputs)==")

                settings.outputs.forEach({ outputType in
                    if outputType != .Transcript {
                        self.addLoadingOutput(type: outputType, settings: outputSettings, outputs: &recording.outputs.outputs)
                    }
                })
                let futures = settings.outputs.map { outputType -> AnyPublisher<Update, OutputGenerationError> in
                  
                    self.generateOutput(transcript: recording.outputs.outputs[0].content, outputType: outputType, outputSettings: outputSettings)
                       .eraseToAnyPublisher()
               }
                
                Publishers.Sequence(sequence: futures)
                    .flatMap { future in
                        future.catch { error -> AnyPublisher<Update, Never> in
                            switch error {
                            case .failure(_, let outputType, _):
                                switch outputType {
                                    case .Summary:
                                    let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Summary})
                                    let out = recording.outputs.outputs[out_idx!]
                                        self.updateErrorOutput(out.id.uuidString, settings: out.settings, outputs: &recording.outputs.outputs)
                                        break
                                    case .Action:
                                    let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Action})
                                    let out = recording.outputs.outputs[out_idx!]
                                        self.updateErrorOutput(out.id.uuidString, settings: out.settings, outputs: &recording.outputs.outputs)
                                        break
                                    case .Title:
                                        recording.title = "Error, tap to retry"
                                    let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Title})
                                    let out = recording.outputs.outputs[out_idx!]
                                        self.updateErrorOutput(out.id.uuidString, settings: out.settings, outputs: &recording.outputs.outputs)
                                            break
                                    case .Transcript:
                                        break
                                    case .Custom:
                                    let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Custom})
                                    let out = recording.outputs.outputs[out_idx!]
                                        self.updateErrorOutput(out.id.uuidString, settings: out.settings, outputs: &recording.outputs.outputs)
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
                            let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Summary})
                            let out = recording.outputs.outputs[out_idx!]
                            self.updateOutput(out.id.uuidString, content: update.content, settings: update.settings, outputs: &recording.outputs.outputs)
                           
                            break
                            case .Action:
                                print("** update: action **")
                            let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Action})
                            let out = recording.outputs.outputs[out_idx!]
                            self.updateOutput(out.id.uuidString, content: update.content, settings: update.settings, outputs: &recording.outputs.outputs)
                                break
                            case .Title:
                                print("** update: Title **")
                            recording.title = update.content
                            let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Title})
                            let out = recording.outputs.outputs[out_idx!]
                            self.updateOutput(out.id.uuidString, content: update.content, settings: update.settings, outputs: &recording.outputs.outputs)
                                break
                            case .Transcript:
                                break
                            case .Custom:
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

        }).store(in: &self.cancellables)
    }
    
    func addLoadingOutput(type: OutputType, settings: OutputSettings, outputs: inout [Output]) -> Output {
        let newOutput = Output(type: type, content: "Loading", settings: settings)
        outputs.append(newOutput)
        return newOutput
    }
    
    func updateOutput(_ id: String, content: String,  settings: OutputSettings, outputs: inout [Output]){
        if let index = outputs.firstIndex(where: { $0.id.uuidString == id }) {
            outputs[index].content = content
            outputs[index].settings = settings
            outputs[index].error = false
            outputs[index].loading = false
        }
    }
    
    func updateErrorOutput(_ id: String, settings: OutputSettings, outputs: inout [Output]) {
        if let index = outputs.firstIndex(where: { $0.id.uuidString == id }) {
            outputs[index].content = "Error, tap to retry"
            outputs[index].error = true
            outputs[index].loading = false
        }
    }
    
    func addErrorOutput(type: OutputType, settings: OutputSettings, outputs: inout [Output]) -> Output {
        let newOutput = Output(type: type, content: "Error, tap to retry", settings: settings)
        newOutput.error = true
        newOutput.loading = false
        outputs.append(newOutput)
        return newOutput
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
        let recording = recordingsList[index]
        if output.type == .Transcript {
            print("== regen transcript and all ==")
            generateAll(recording: recording, fileURL: getAudioURL(filePath:recording.filePath))
            return
        }
        let transcript = getTranscript(outputs: recording.outputs.outputs)
        let recordingMetadataURL = getRecordingMetaURL(filePath: recording.filePath)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

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
                switch update.type {
                    case .Summary:
                        print("** update: summary **")
                    self.updateOutput(output.id.uuidString, content: update.content, settings: update.settings, outputs: &recording.outputs.outputs)
                       
                        break
                    case .Action:
                        print("** update: action **")
                        self.updateOutput(output.id.uuidString, content: update.content, settings: update.settings, outputs: &recording.outputs.outputs)
                      
                        break
                    case .Title:
                        print("** update: Title **")
                        recording.title = update.content
                        self.updateOutput(output.id.uuidString, content: update.content, settings: update.settings, outputs: &recording.outputs.outputs)
                        break
                    case .Transcript:
                        break
                    case .Custom:
                        break
                }
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
        let recording = recordingsList[index]
        let transcript = getTranscript(outputs: recording.outputs.outputs)
        let recordingMetadataURL = getRecordingMetaURL(filePath: recording.filePath)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let custom_out = addLoadingOutput(type: .Custom, settings: outputSettings, outputs: &recording.outputs.outputs)
        //recordingsList[index] = recording
        generateOutput(transcript: transcript, outputType: .Custom, outputSettings: outputSettings).sink(
            receiveCompletion: { completion in
                switch (completion) {
                    case .failure(_):
                    self.updateErrorOutput(custom_out.id.uuidString, settings: outputSettings, outputs: &recording.outputs.outputs)
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
                self.updateOutput(custom_out.id.uuidString, content: update.content, settings: outputSettings, outputs: &recording.outputs.outputs)
                do {
                    let updatedData = try encoder.encode(recording)
                    try updatedData.write(to: recordingMetadataURL)
                    print("** recording after custom output **")
                    print(recording)
                    self.recordingsList[index] = recording
                } catch {
                    print("error saving updated output")
                }
            })
        .store(in: &self.cancellables)
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
                print("settings dict \(settingsDictionary!)")
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
                                print("AF failure \(error)")
                                promise(.failure(OutputGenerationError.failure(error: error, outputType: outputType, transcript: transcript)))
                        }
                }

            } catch {
                print("encoding error \(error)")
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
                let fileData = try Data(contentsOf: self.getAudioURL(filePath: recording.filePath))
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
                
                if let dataString = String(data: data, encoding: .utf8) {
                       print("Data received: \(dataString)")
                   } else {
                       print("Unable to convert data to text")
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
    
    func refreshRecordingOutputs(recording: ObservableRecording, outputs: Outputs) {
        let filePath = recording.filePath
        if let index = recordingsList.firstIndex(where: { $0.filePath == filePath }) {
            recordingsList[index].outputs = outputs
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
        
        
        let url = getAudioURL(filePath: filePath)
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
            if(audioPlayerEnabled){
                stopPlaying(index: audioPlayerCurrentIndex)
            }
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayerCurrentURL = audioPlayer.url
            audioPlayerCurrentIndex = index
            audioPlayerEnabled = true
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            audioPlayer.currentTime = recordingsList[index].absProgress
            audioPlayer.play()
  
        let updatedRecording = recordingsList[index]
        updatedRecording.isPlaying = true
        recordingsList[index] = updatedRecording
        print(self.formatter
            .string(from:
                   TimeInterval(audioPlayer.duration))!)
        print(self.formatter
            .string(from:
                        TimeInterval(self.audioPlayer.duration))!)
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: audioPlayer.isPlaying){ _ in
            if(self.recordingsList[index].isPlaying){
                let updatedRecording = self.recordingsList[index]
                
                updatedRecording.currentTime = self.formatter.string(from: TimeInterval(self.audioPlayer.currentTime))!
                print(updatedRecording.currentTime)
                updatedRecording.progress = CGFloat(self.audioPlayer.currentTime / self.audioPlayer.duration)
                updatedRecording.absProgress = self.audioPlayer.currentTime
                self.recordingsList[index] = updatedRecording
                self.objectWillChange.send()
                
                if (self.audioPlayer.currentTime >= self.audioPlayer.duration) {
                    print("reached")
                    updatedRecording.absProgress = 0.0
                    self.recordingsList[index].progress = 0
                    self.recordingsList[index].isPlaying = false
                    self.recordingsList[index].currentTime = self.formatter.string(from: TimeInterval(0.0))!
                }
                
            }
                self.objectWillChange.send()
             
        }
            
        } catch {
            print("Audioplayer failed: \(error)")
        }

    }
    
    func stopPlaying(index: Int) {
        if(audioPlayerEnabled){
            print("stopping playing")
            print("\(audioPlayer.currentTime)")
            let updatedRecording = recordingsList[index]
            updatedRecording.isPlaying = false
            recordingsList[index] = updatedRecording
            audioPlayer.pause()
            self.objectWillChange.send()
        }
    }
    
    func forward15(index: Int, filePath : String) {
        if(audioPlayerCurrentURL != getAudioURL(filePath: filePath) || !audioPlayerEnabled){
            startPlaying(index: index, filePath: filePath)
        }
        if(audioPlayerEnabled){
            if(!recordingsList[index].isPlaying){
                audioPlayer.pause()
            }
            let increase = audioPlayer.currentTime + 15
            if increase < audioPlayer.duration {
                audioPlayer.currentTime = increase
            } else {
                stopPlaying(index: index)
                audioPlayer.currentTime = 0
            }
            let updatedRecording = self.recordingsList[index]
            
            updatedRecording.currentTime = self.formatter.string(from: TimeInterval(self.audioPlayer.currentTime))!
            print(updatedRecording.currentTime)
            updatedRecording.progress = CGFloat(self.audioPlayer.currentTime / self.audioPlayer.duration)
            updatedRecording.absProgress = self.audioPlayer.currentTime
            updatedRecording.isPlaying = audioPlayer.isPlaying
            self.recordingsList[index] = updatedRecording
            self.objectWillChange.send()
        }
        else{
            print("error: audio player not enabled")
        }
    }
    
    func backwards15(index: Int, filePath : String) {
        if(audioPlayerCurrentURL != getAudioURL(filePath: filePath) || !audioPlayerEnabled){
            startPlaying(index: index, filePath: filePath)
        }
        if(audioPlayerEnabled){
            let decrease = audioPlayer.currentTime - 15
            if decrease > 0 {
                audioPlayer.currentTime = decrease
            } else {
                audioPlayer.currentTime = 0
            }
            let updatedRecording = self.recordingsList[index]
            
            updatedRecording.currentTime = self.formatter.string(from: TimeInterval(self.audioPlayer.currentTime))!
            print(updatedRecording.currentTime)
            updatedRecording.progress = CGFloat(self.audioPlayer.currentTime / self.audioPlayer.duration)
            updatedRecording.absProgress = self.audioPlayer.currentTime
            self.recordingsList[index] = updatedRecording
            self.objectWillChange.send()
        }
        else{
            print("error: audio player not enabled")
        }
    }
            
    
    func seekTo(time: TimeInterval, index: Int){
        self.audioPlayer.currentTime = time
    }
    
    func deleteOutput(index: Int, output: Output) {
        let updatedRecording = recordingsList[index]
        if let idxToDelete = updatedRecording.outputs.outputs.firstIndex(where: {$0.id == output.id}) {
            updatedRecording.outputs.outputs.remove(at: idxToDelete)
            //recordingsList[index] = updatedRecording
            let recordingMetadataURL = getRecordingMetaURL(filePath: updatedRecording.filePath)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601 // to properly encode the Date field
            do {
                let updatedData = try encoder.encode(updatedRecording)
                try updatedData.write(to: recordingMetadataURL)
                print("** recording after regenerated output **")
            } catch {
                print("error saving updated output")
            }
        }
    }
    
    func deleteRecording(audioPath: String) {
        cancellables.removeAll()
        let oldAudioURL = getAudioURL(filePath: audioPath)
        let oldMetaURL = getRecordingMetaURL(filePath: audioPath)
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let recentlyDeletedFolder = applicationSupportDirectory.appendingPathComponent("Recently Deleted")
        // if curr folder == recently deleted, perma delete
        if (recentlyDeletedFolder.lastPathComponent == URL(filePath: folderPath).lastPathComponent) {
            print("Deleting permanently")
            do {
                try fileManager.removeItem(at: oldAudioURL)
            } catch {
                print("can't delete audio \(error)")
            }
            
            do {
                try fileManager.removeItem(at: oldMetaURL)
            } catch {
                print("can't delete meta \(error)")
            }
            return
        }
        // move to recently deleted
        let newAudioURL = recentlyDeletedFolder.appendingPathComponent("raw/\(URL(filePath: audioPath).lastPathComponent)")
        let newMetaURL = recentlyDeletedFolder.appendingPathComponent(oldMetaURL.lastPathComponent)
        
        do {
            try fileManager.moveItem(at: oldAudioURL, to: newAudioURL)
        } catch {
            print("can't move audio\(error)")
        }
                                                                    
        do {
            try fileManager.moveItem(at: oldMetaURL, to: newMetaURL)
        } catch {
            print("can't move meta\(error)")
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
    
    func getAudioURL(filePath: String) -> URL {
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
