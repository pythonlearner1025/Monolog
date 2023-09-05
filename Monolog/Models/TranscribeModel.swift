//
//  TranscribeModel.swift
//  Monolog
//
//  Created by minjune Song on 9/3/23.
//

import Foundation
import AudioKit
import SwiftWhisper

class TranscribeModel: WhisperDelegate {
    
    func transcribe(audioURL: URL, completionHandler: @escaping (Result<String, Error>) -> Void) {
        guard let fileURL = Bundle.main.url(forResource: "ggml-tiny", withExtension: "bin") else {
            completionHandler(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file not found"])))
            return
        }
        
        let whisper = Whisper(fromFileURL: fileURL)
        // Assuming `self` conforms to `WhisperDelegate`
        whisper.delegate = self

        convertAudioFileToPCMArray(fileURL: audioURL) { result in
            switch result {
            case .success(let floats):
                print("Conversion to PCM floats success")
                
                Task {
                    do {
                        let segments = try await whisper.transcribe(audioFrames: floats)
                        let transcript = segments.map(\.text).joined()
                        print("Transcribed audio:", transcript)
                        completionHandler(.success(transcript))
                    } catch {
                        print("An error occurred during transcription \(error)")
                        completionHandler(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("An error occurred during conversion \(error)")
                completionHandler(.failure(error))
            }
        }
    }

    func convertAudioFileToPCMArray(fileURL: URL, completionHandler: @escaping (Result<[Float], Error>) -> Void) {
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = 16000
        options.bitDepth = 16
        options.channels = 1
        options.isInterleaved = false

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let converter = FormatConverter(inputURL: fileURL, outputURL: tempURL, options: options)
        converter.start { error in
            if let error {
                completionHandler(.failure(error))
                return
            }

            let data = try! Data(contentsOf: tempURL) // Handle error here

            let floats = stride(from: 44, to: data.count, by: 2).map {
                return data[$0..<$0 + 2].withUnsafeBytes {
                    let short = Int16(littleEndian: $0.load(as: Int16.self))
                    return max(-1.0, min(Float(short) / 32767.0, 1.0))
                }
            }

            try? FileManager.default.removeItem(at: tempURL)

            completionHandler(.success(floats))
        }
    }
    
    func whisper(_ aWhisper: Whisper, didUpdateProgress progress: Double) {
       print("Progress: \(progress)")
    }
 
    func whisper(_ aWhisper: Whisper, didProcessNewSegments segments: [Segment], atIndex index: Int) {
       print("New segments: \(segments)")
    }

    func whisper(_ aWhisper: Whisper, didCompleteWithSegments segments: [Segment]) {
       print("Completed with segments: \(segments)")
    }

    func whisper(_ aWhisper: Whisper, didErrorWith error: Error) {
       print("Error occurred: \(error)")
    }
}
