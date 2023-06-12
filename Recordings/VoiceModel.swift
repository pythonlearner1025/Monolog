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

class AudioRecorderModel : NSObject, ObservableObject {
    let encoder : JSONEncoder
    var formatter : DateComponentsFormatter
    var audioRecorder : AVAudioRecorder!
    let recordingSettings = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 12000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    let baseURL = "https://turing-api.com/api/v1/"
    private var cancellables = Set<AnyCancellable>()
    override init(){
        self.formatter = DateComponentsFormatter()
        self.formatter.allowedUnits = [.minute, .second]
        self.formatter.unitsStyle = .positional
        self.formatter.zeroFormattingBehavior = [ .pad ]
        self.encoder = JSONEncoder()    
        self.encoder.dateEncodingStrategy = .iso8601
        super.init()
    }
    func startRecording(audioURL: URL) {
        let recordingSession = AVAudioSession.sharedInstance()
        do {
           try recordingSession.setCategory(.playAndRecord, mode: .default)
           try recordingSession.setActive(true)
        } catch {
           print("Cannot setup the Recording")
        }
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: recordingSettings)
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            
        } catch {
            print("Failed to Setup the Recording")
        }
    }
    
    func stopRecording(_ recordings: inout [Recording], folderURL: URL) {
        audioRecorder.stop()
        // write Recordings to localStorage as well.
        let audioURL = audioRecorder.url
        let filePath = "\(audioURL.lastPathComponent).json"
        let recording = Recording(folderPath: folderURL.lastPathComponent, audioPath: audioURL.lastPathComponent, filePath: filePath, createdAt: getFileDate(for: audioURL), isPlaying: false, title: "Untitled", outputs: Outputs())
        recordings.insert(recording, at: 0)
        generateAll(recording: recording, audioURL: audioURL)
    }
    
    func saveImportedRecording(_ recordings: inout [Recording], oldAudioURL: URL, newAudioURL: URL, folderURL: URL){
        let fileManager = FileManager.default
        do {
            try fileManager.copyItem(at: oldAudioURL, to: newAudioURL)
        } catch {
            print("An error occurred while copying the file: \(error)")
        }
        let filePath = "\(newAudioURL.lastPathComponent).json"
        let recording = Recording(folderPath: folderURL.lastPathComponent, audioPath: newAudioURL.lastPathComponent, filePath: filePath, createdAt: getFileDate(for: oldAudioURL), isPlaying: false, title: "Untitled", outputs: Outputs())
        recordings.insert(recording, at: 0)
        generateAll(recording: recording, audioURL: newAudioURL)
    }
    
    func generateAll(recording: Recording, audioURL: URL) {
       let folderURL = Util.buildFolderURL(recording.folderPath)
       let fileURL = folderURL.appendingPathComponent("\(audioURL.lastPathComponent).json")
       do {
           let data = try encoder.encode(recording)
           print("Saving generateALL results here:")
           print(fileURL)
           try data.write(to: fileURL)
       } catch {
           print("An error occurred while saving the recording object: \(error)")
       }
        var transcript_out = Output(type: .Transcript, content: "Loading", settings: OutputSettings.defaultSettings)
        if !recording.outputs.outputs.contains(where: {$0.type == .Transcript}) {
            recording.outputs.outputs.append(transcript_out)
        } else {
            transcript_out = recording.outputs.outputs.first(where: {$0.type == .Transcript})!
        }
        generateTranscription(recording: recording).sink(receiveCompletion: { [self] (completion) in
            switch completion {
            case .failure(let error):
                print("An error occurred while generating transcript: \(error)")
                self.updateErrorOutput(transcript_out.id.uuidString, settings: OutputSettings.defaultSettings, outputs: recording.outputs)
                do {
                    print("-- saving transcript error data --")
                    print(recording)
                    let updatedData = try self.encoder.encode(recording)
                    try updatedData.write(to: fileURL)
                } catch {
                    print("Error saving generate-transcript-error to recording: \(error)")
                }
            case .finished:
                break
            }
        }, receiveValue: { update in
            print("* update: Transcript **")
            self.updateOutput(transcript_out.id.uuidString, content: update.content, settings: update.settings, outputs: recording.outputs)
            do {
                let updatedData = try self.encoder.encode(recording)
                try updatedData.write(to: fileURL)
            } catch {
                print("An error occurred while updating the recording object: \(error)")
            }
            if let settings = UserDefaults.standard.getSettings(forKey: "Settings") {
                let outputSettings = OutputSettings(length: settings.length, format: settings.format, tone: settings.tone,  name: "Default Output", prompt: "")
                print("== all settings outputs \(settings.outputs)==")

                settings.outputs.forEach({ outputType in
                    if outputType != .Transcript {
                        self.addLoadingOutput(type: outputType, settings: outputSettings, outputs:  recording.outputs)
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
                                        self.updateErrorOutput(out.id.uuidString, settings: out.settings, outputs:  recording.outputs)
                                    case .Action:
                                        let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Action})
                                        let out = recording.outputs.outputs[out_idx!]
                                        self.updateErrorOutput(out.id.uuidString, settings: out.settings, outputs:  recording.outputs)
                                    case .Title:
                                        recording.title = "Error, tap to retry"
                                        let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Title})
                                        let out = recording.outputs.outputs[out_idx!]
                                        self.updateErrorOutput(out.id.uuidString, settings: out.settings, outputs:  recording.outputs)
                                    case .Transcript:
                                        break
                                    case .Custom:
                                        let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Custom})
                                        let out = recording.outputs.outputs[out_idx!]
                                        self.updateErrorOutput(out.id.uuidString, settings: out.settings, outputs:  recording.outputs)
                                }
                                do {
                                    let updatedData = try self.encoder.encode(recording)
                                    try updatedData.write(to: fileURL)
                                }
                                catch {
                                    print("Error saving output-generate-error to recording: \(error)")
                                }
                                return Empty(completeImmediately: true).eraseToAnyPublisher()

                            }
                    
                        }
                    }
                    .sink(receiveCompletion: { _ in }, receiveValue: { update in
                        switch update.type {
                            case .Summary:
                                print("** update: summary **")
                                let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Summary})
                                let out = recording.outputs.outputs[out_idx!]
                                out.loading = false
                                out.error = false
                                out.content = update.content
                                out.settings = update.settings
                                
                            case .Action:
                                print("** update: action **")
                                let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Action})
                                let out = recording.outputs.outputs[out_idx!]
                                out.loading = false
                                out.error = false
                                out.content = update.content
                                out.settings = update.settings
                                
                          
                            case .Title:
                                print("** update: Title **")
                                recording.title = update.content
                                let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Title})
                                let out = recording.outputs.outputs[out_idx!]
                                out.loading = false
                                out.error = false
                                out.content = update.content
                                out.settings = update.settings
                                
                          
                            case .Transcript:
                                break
                            case .Custom:
                                break
                        }
                        do {
                            let updatedData = try self.encoder.encode(recording)
                            try updatedData.write(to: fileURL)
                        }
                        catch {
                            print("An error occurred while saving the recording object: \(error)")
                        }
                    })
                   .store(in: &self.cancellables)
            }

        }).store(in: &self.cancellables)
    }
    
    func addLoadingOutput(type: OutputType, settings: OutputSettings, outputs: Outputs) -> Output {
        let newOutput = Output(type: type, content: "Loading", settings: settings)
        outputs.outputs.append(newOutput)
        return newOutput
    }
    
    func updateOutput(_ id: String, content: String,  settings: OutputSettings, outputs: Outputs){
        if let index = outputs.outputs.firstIndex(where: { $0.id.uuidString == id }) {
            outputs.outputs[index].content = content
            outputs.outputs[index].settings = settings
            outputs.outputs[index].error = false
            outputs.outputs[index].loading = false
        }
    }
    
    func updateErrorOutput(_ id: String, settings: OutputSettings, outputs: Outputs) {
        if let index = outputs.outputs.firstIndex(where: { $0.id.uuidString == id }) {
            outputs.outputs[index].content = "Error, tap to retry"
            outputs.outputs[index].error = true
            outputs.outputs[index].loading = false
        }
    }
    
    func addErrorOutput(type: OutputType, settings: OutputSettings, outputs: Outputs) -> Output {
        let newOutput = Output(type: type, content: "Error, tap to retry", settings: settings)
        newOutput.error = true
        newOutput.loading = false
        outputs.outputs.append(newOutput)
        return newOutput
    }
    
    func getTranscript(outputs: Outputs) -> String {
        if let index = outputs.outputs.firstIndex(where: {$0.type == .Transcript}) {
            return outputs.outputs[index].content
        } else {
            return ""
        }
    }
    
    func regenerateOutput(recording: Recording, output: Output) {
        if output.type == .Transcript {
            generateAll(recording: recording, audioURL: URL(fileURLWithPath: recording.audioPath))
            return
        }
        let transcript = getTranscript(outputs: recording.outputs)
        generateOutput(transcript: transcript, outputType: output.type, outputSettings: output.settings).sink(
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
                    self.updateOutput(output.id.uuidString, content: update.content, settings: update.settings, outputs:  recording.outputs)
                       
                        break
                    case .Action:
                        print("** update: action **")
                        self.updateOutput(output.id.uuidString, content: update.content, settings: update.settings, outputs:  recording.outputs)
                      
                        break
                    case .Title:
                        print("** update: Title **")
                        recording.title = update.content
                        self.updateOutput(output.id.uuidString, content: update.content, settings: update.settings, outputs:  recording.outputs)
                        break
                    case .Transcript:
                        break
                    case .Custom:
                        break
                }
                do {
                    let updatedData = try self.encoder.encode(recording)
                    let folderURL = Util.buildFolderURL(recording.folderPath)
                    let fileURL = folderURL.appendingPathComponent(recording.filePath)
                    try updatedData.write(to: fileURL)
                } catch {
                    print("error saving updated output")
                }
            })
            .store(in: &self.cancellables)
    }
    
    func generateCustomOutput(recording: Recording, outputSettings: OutputSettings) {
        let transcript = getTranscript(outputs: recording.outputs)
        let custom_out = addLoadingOutput(type: .Custom, settings: outputSettings, outputs: recording.outputs)
        generateOutput(transcript: transcript, outputType: .Custom, outputSettings: outputSettings).sink(
            receiveCompletion: { completion in
                switch (completion) {
                    case .failure(_):
                    self.updateErrorOutput(custom_out.id.uuidString, settings: outputSettings, outputs: recording.outputs)
                        do {
                            print("-- saving custom output error data --")
                            let updatedData = try self.encoder.encode(recording)
                            try updatedData.write(to: URL(fileURLWithPath: recording.filePath))
                        }
                        catch {
                            print("Error saving output-generate-error to recording: \(error)")
                        }
                        break
                    case .finished:
                        break
                }
            },
            receiveValue: { update in
                self.updateOutput(custom_out.id.uuidString, content: update.content, settings: outputSettings, outputs:  recording.outputs)
                do {
                    let updatedData = try self.encoder.encode(recording)
                    let folderURL = Util.buildFolderURL(recording.folderPath)
                    let fileURL = folderURL.appendingPathComponent(recording.filePath)
                    try updatedData.write(to: fileURL)
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
            
            do {
                let encodedSettings = try self.encoder.encode(outputSettings)
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
                                promise(.failure(OutputGenerationError.failure(error: error, outputType: outputType, transcript: transcript)))
                        }
                }

            } catch {
                print("encoding error \(error)")
            }
        }
    }

    func generateTranscription(recording: Recording) -> Future<Update, Error> {
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
            data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(recording.audioPath)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)

            do {
                let rawFolderURL = Util.buildFolderURL(recording.folderPath).appendingPathComponent("raw")
                let audioURL = rawFolderURL.appendingPathComponent(recording.audioPath)
                let fileData = try Data(contentsOf: audioURL)
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
    
    func cancelSave() {
        cancellables.removeAll()
    }
    
}

class AudioPlayerModel : NSObject, ObservableObject, AVAudioPlayerDelegate{
    @Published var audioPlayer : AVAudioPlayer!
    @Published var isPlaying : Bool = false
    var indexOfPlayer = 0
    let audioPath: String
    
    @Published var progress: CGFloat = 0.0
    @Published var absProgress: Double = 0.0
    @Published var currentTime: String = "00:00"
    var formatter : DateComponentsFormatter
        
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

    // TODO: major changes to start / stop playing
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
            Timer.scheduledTimer(withTimeInterval: 0.01, repeats: audioPlayer.isPlaying){ _ in
                if(self.isPlaying){
                    self.currentTime = self.formatter.string(from: TimeInterval(self.audioPlayer.currentTime))!
                    self.progress = CGFloat(self.audioPlayer.currentTime / self.audioPlayer.duration)
                    self.absProgress = self.audioPlayer.currentTime
                    if (self.audioPlayer.currentTime >= self.audioPlayer.duration) {
                        self.absProgress = 0.0
                        self.progress = 0
                        self.currentTime = self.formatter.string(from: TimeInterval(0.0))!
                    }
            }
        }
            
        } catch {
            print("Audioplayer failed: \(error)")
        }

    }
    
    func stopPlaying() {
        if(isPlaying){
            audioPlayer.pause()
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
