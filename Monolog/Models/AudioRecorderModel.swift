//
//  AudioRecorderModel.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import Foundation
import AVFoundation
import Combine
import Alamofire
import UIKit

class AudioRecorderModel : NSObject, ObservableObject {
    @Published var isPlaying : Bool = false
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
    var cancellables = Set<AnyCancellable>()
    
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
            try recordingSession.setCategory(.playAndRecord, mode: .default, options:  .defaultToSpeaker)
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
    
    func stopRecording(_ recordings: inout [Recording], folderURL: URL, generateText: Bool) {
        audioRecorder.stop()
        // write Recordings to localStorage as well.
        let audioURL = audioRecorder.url
        let filePath = "\(audioURL.lastPathComponent).json"
        let recording = Recording(folderPath: folderURL.lastPathComponent, audioPath: audioURL.lastPathComponent, filePath: filePath, createdAt: getFileDate(for: audioURL), title: "Untitled", outputs: Outputs.defaultOutputs, generateText: generateText)
        recordings.insert(recording, at: 0)
        if generateText {
            generateAll(recording: recording, audioURL: audioURL)
        } else {
            for output in recording.outputs.outputs {
                output.status = .restricted
            }
            let folderURL = Util.buildFolderURL(recording.folderPath)
            let fileURL = folderURL.appendingPathComponent("\(audioURL.lastPathComponent).json")
            do {
                let data = try encoder.encode(recording)
                try data.write(to: fileURL)
            } catch {
                print("An error occurred while saving the recording object: \(error)")
            }
        }
    }
    
    func saveImportedRecording(_ recordings: inout [Recording], oldAudioURL: URL, newAudioURL: URL, folderURL: URL, generateText: Bool){
        let fileManager = FileManager.default
        do {
            try fileManager.copyItem(at: oldAudioURL, to: newAudioURL)
        } catch {
            print("An error occurred while copying the file: \(error)")
        }
        let filePath = "\(newAudioURL.lastPathComponent).json"
        let recording = Recording(folderPath: folderURL.lastPathComponent, audioPath: newAudioURL.lastPathComponent, filePath: filePath, createdAt: getFileDate(for: oldAudioURL), title: "Untitled", outputs: Outputs.defaultOutputs, generateText: generateText)
        recordings.insert(recording, at: 0)
        if generateText {
            generateAll(recording: recording, audioURL: newAudioURL)
        } else {
            for output in recording.outputs.outputs {
                output.status = .restricted
            }
            let folderURL = Util.buildFolderURL(recording.folderPath)
            let fileURL = folderURL.appendingPathComponent("\(newAudioURL.lastPathComponent).json")
            do {
                let data = try encoder.encode(recording)
                try data.write(to: fileURL)
            } catch {
                print("An error occurred while saving the recording object: \(error)")
            }
        }
    }
    
    func generateAll(recording: Recording, audioURL: URL, transcriptCompletion: (() -> Void)? = nil) {
       let folderURL = Util.buildFolderURL(recording.folderPath)
       let fileURL = folderURL.appendingPathComponent("\(audioURL.lastPathComponent).json")
       do {
           let data = try encoder.encode(recording)
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
        let transcriptCancellable = generateTranscription(recording: recording).sink(receiveCompletion: { [self] (completion) in
            switch completion {
            case .failure(let error):
                print("An error occurred while generating transcript: \(error)")
                self.updateAllErrorOutput(outputs: recording.outputs)
                
                do {
                    let updatedData = try self.encoder.encode(recording)
                    try updatedData.write(to: fileURL)
                } catch {
                    print("Error saving generate-transcript-error to recording: \(error)")
                }
            case .finished:
                break
            }
        }, receiveValue: { update in
            self.updateOutput(transcript_out.id.uuidString, content: update.content, settings: update.settings, outputs: recording.outputs)
            transcriptCompletion?()
            do {
                let updatedData = try self.encoder.encode(recording)
                try updatedData.write(to: fileURL)
            } catch {
                print("An error occurred while updating the recording object: \(error)")
            }
            if let settings = UserDefaults.standard.getSettings(forKey: "Settings") {
                var outputSettings = UserDefaults.standard.getOutputSettings(forKey: "Output Settings") ?? UserDefaults.standard.defaultOutputSettings
                outputSettings.name = ""
                outputSettings.prompt = ""
                settings.outputs.forEach({ outputType in
                    if outputType != .Transcript {
                        self.addLoadingOutput(type: outputType, settings: outputSettings, outputs:  recording.outputs)
                    }
                })
                let futures = settings.outputs.map { outputType -> AnyPublisher<Update, OutputGenerationError> in
                    self.generateOutput(transcript: !transcript_out.content.isEmpty ? transcript_out.content : "No transcript", outputType: outputType, outputSettings: outputSettings)
                       .eraseToAnyPublisher()
               }
                
               let sequenceCancellables = Publishers.Sequence(sequence: futures)
                    .flatMap { future in
                        future.catch { error -> AnyPublisher<Update, Never> in
                            switch error {
                            case .failure(_, let outputType, _):
                                switch outputType {
                                    case .Summary:
                                        let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Summary})
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
                    .sink(receiveCompletion: { _ in}, receiveValue: { update in
                        switch update.type {
                            case .Summary:
                                let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Summary})
                                let out = recording.outputs.outputs[out_idx!]
                                out.status = .completed
                                out.content = update.content
                                out.settings = update.settings
                            case .Title:
                                recording.title = update.content
                                let out_idx = recording.outputs.outputs.firstIndex(where: {$0.type == .Title})
                                let out = recording.outputs.outputs[out_idx!]
                                out.status = .completed
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
    
    func regenerateAll(recording: Recording, completion: @escaping () -> Void) {
        updateAllLoadingOutput(outputs: recording.outputs)
        generateAll(recording: recording, audioURL: URL(fileURLWithPath: recording.audioPath)) {
            print("transcript completion function")
            for output in recording.outputs.outputs {
                if output.type == .Custom {
                    self.regenerateOutput(recording: recording, output: output)
                }
            }
        }
        completion()
    }
    
    func regenerateOutput(recording: Recording, output: Output) {
        output.content = "Loading"
        output.status == .loading
        let transcript = getTranscript(outputs: recording.outputs)
        print("regen output")
        print(transcript)
        generateOutput(transcript: transcript, outputType: output.type, outputSettings: output.settings).sink(
            receiveCompletion: { completion in
                switch (completion) {
                case .failure(let error):
                    //print("failed to regenerate \(error)")
                    output.content = "Error, tap to retry"
                    output.status == .error
                case .finished:
                    break
                }
            },
            receiveValue:{ update in
                switch update.type {
                    case .Summary:
                        self.updateOutput(output.id.uuidString, content: update.content, settings: update.settings, outputs:  recording.outputs)
                        break
                    case .Title:
                        recording.title = update.content
                        self.updateOutput(output.id.uuidString, content: update.content, settings: update.settings, outputs:  recording.outputs)
                        break
                    case .Transcript:
                        break
                    case .Custom:
                        self.updateOutput(output.id.uuidString, content: update.content, settings: update.settings, outputs: recording.outputs)
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
    
    func generateTransform(recording: Recording, transformType: TransformType, outputSettings: OutputSettings) {
        let transcript = getTranscript(outputs: recording.outputs)
        let custom_out = addLoadingOutput(type: .Custom, settings: outputSettings, outputs: recording.outputs)
        generateTransformOutput(transcript: transcript, transformType: transformType, outputSettings: outputSettings).sink(
            receiveCompletion: { completion in
                switch (completion) {
                    case .failure(_):
                    self.updateErrorOutput(custom_out.id.uuidString, settings: outputSettings, outputs: recording.outputs)
                        do {
                            let updatedData = try self.encoder.encode(recording)
                            let recordingPath = Util.buildFolderURL(recording.folderPath).appendingPathComponent(recording.filePath)
                            try updatedData.write(to: recordingPath)
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
   
    func generateTransformOutput(transcript: String, transformType: TransformType, outputSettings: OutputSettings) -> Future<Update, OutputGenerationError> {
        return Future { promise in
            var taskId: UIBackgroundTaskIdentifier!
                taskId = UIApplication.shared.beginBackgroundTask {
                    UIApplication.shared.endBackgroundTask(taskId)
                    taskId = .invalid
            }
            
            let url = self.baseURL + "generate_transformation"
            
            do {
                let encodedSettings = try self.encoder.encode(outputSettings)
                let settingsDictionary = try JSONSerialization.jsonObject(with: encodedSettings, options: .allowFragments) as? [String: Any]
                let parameters: [String: Any] = [
                    "type": transformType.rawValue,
                    "transcript": transcript,
                    "settings": settingsDictionary ?? [:]
                ]
                
                AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                    .validate()
                    .responseJSON { response in
                        UIApplication.shared.endBackgroundTask(taskId) // End the background task when the request completes
                        print(response.description)
                        switch response.result {
                            case .success(let value):
                                if let JSON = value as? [String: Any] {
                                    let output = JSON["out"] as? String ?? ""
                                    let update = Update(type: .Custom, content: output, settings: outputSettings)
                                    promise(.success(update))
                                }
                            case .failure(let error):
                            promise(.failure(OutputGenerationError.failure(error: error, outputType: .Custom, transcript: transcript)))
                        }
                }
            } catch {
                print("encoding error \(error)")
                UIApplication.shared.endBackgroundTask(taskId) // End the background task if there is an error
            }
        }
    }

    
    func generateOutput(transcript: String, outputType: OutputType, outputSettings: OutputSettings) -> Future<Update, OutputGenerationError> {
        return Future { promise in
            var taskId: UIBackgroundTaskIdentifier!
                taskId = UIApplication.shared.beginBackgroundTask {
                    UIApplication.shared.endBackgroundTask(taskId)
                    taskId = .invalid
            }
            
            let url = self.baseURL + "generate_output"
            
            do {
                let encodedSettings = try self.encoder.encode(outputSettings)
                let settingsDictionary = try JSONSerialization.jsonObject(with: encodedSettings, options: .allowFragments) as? [String: Any]
                let parameters: [String: Any] = [
                    "type": outputType.rawValue,
                    "transcript": transcript,
                    "settings": settingsDictionary ?? [:]
                ]
                
                AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                    .validate()
                    .responseJSON { response in
                        UIApplication.shared.endBackgroundTask(taskId) // End the background task when the request completes
                        print(response.description)
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
                UIApplication.shared.endBackgroundTask(taskId) // End the background task if there is an error
            }
        }
    }

    
    func generateTranscription(recording: Recording) -> Future<Update, Error> {
        return Future { promise in
            let backgroundTaskId = UIApplication.shared.beginBackgroundTask {
                // This block will be executed if the task expires
                promise(.failure(NSError(domain: "com.yourapp", code: 0, userInfo: [NSLocalizedDescriptionKey: "Background task expired"])))
            }

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
                //print("Failed to read file data: \(error)")
                promise(.failure(error))
                return
            }

            data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            // Set the HTTPBody with the form data we created
            request.httpBody = data
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                // Make sure to end the background task when done
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
                
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
    
    func cancelSave() {
        cancellables.removeAll()
    }
    
}

// helpers
extension AudioRecorderModel {
    private func addLoadingOutput(type: OutputType, settings: OutputSettings, outputs: Outputs) -> Output {
        if let index = outputs.outputs.firstIndex(where: { $0.type == type }) {
            if type != .Custom {
                return outputs.outputs[index]
            }
        }
        let newOutput = Output(type: type, content: "Loading", settings: settings)
        outputs.outputs.append(newOutput)
        return newOutput
    }
    
    private func updateOutput(_ id: String, content: String,  settings: OutputSettings, outputs: Outputs){
        if let index = outputs.outputs.firstIndex(where: { $0.id.uuidString == id }) {
            outputs.outputs[index].content = content
            outputs.outputs[index].settings = settings
            outputs.outputs[index].status = .completed
        }
    }
    
    private func updateAllLoadingOutput(outputs: Outputs) {
        for output in outputs.outputs {
            output.content = "Loading"
            output.status = .loading
        }
    }
    
    private func updateAllErrorOutput(outputs: Outputs) {
        for output in outputs.outputs {
            output.content = "Error, tap to retry"
            output.status = .error
        }
    }
    
    private func updateErrorOutput(_ id: String, settings: OutputSettings, outputs: Outputs) {
        if let index = outputs.outputs.firstIndex(where: { $0.id.uuidString == id }) {
            outputs.outputs[index].content = "Error, tap to retry"
            outputs.outputs[index].status = .error
        }
    }
    
    private func addErrorOutput(type: OutputType, settings: OutputSettings, outputs: Outputs) -> Output {
        let newOutput = Output(type: type, content: "Error, tap to retry", settings: settings)
        newOutput.status = .error
        outputs.outputs.append(newOutput)
        return newOutput
    }
    
    private func getTranscript(outputs: Outputs) -> String {
        if let index = outputs.outputs.firstIndex(where: {$0.type == .Transcript}) {
            return outputs.outputs[index].content
        } else {
            return ""
        }
    }
}
