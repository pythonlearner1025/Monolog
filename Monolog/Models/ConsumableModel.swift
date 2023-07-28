//
//  ConsumableModel.swift
//  Monolog
//
//  Created by minjune Song on 6/26/23.
//

import Foundation
import KeychainSwift
import SwiftUI

class ConsumableModel: ObservableObject {
    private let maxTranscripts: Int = 20
    private let maxOutputs: Int = 20
    
    init (){
        let keychain = KeychainSwift()
        
        if keychain.get("isFirstLaunch") == nil {
            keychain.set("0", forKey: "transcripts")
            keychain.set("0", forKey: "outputs")
            keychain.set("false", forKey: "isFirstLaunch")
        }
    }
    
    func useTranscript() {
        let keychain = KeychainSwift()
        if let currentTranscripts = keychain.get("transcripts") {
            if let currentTranscriptsInt = Int(currentTranscripts), currentTranscriptsInt < maxTranscripts {
                let newTranscripts = currentTranscriptsInt + 1
                keychain.set(String(newTranscripts), forKey: "transcripts")
            } else {
                print("No transcripts left to consume.")
            }
        }
    }
    
    func useOutput() {
        let keychain = KeychainSwift()
        if let currentOutputs = keychain.get("outputs") {
            if let currentOutputsInt = Int(currentOutputs), currentOutputsInt < maxOutputs {
                let newOutputs = currentOutputsInt + 1
                keychain.set(String(newOutputs), forKey: "outputs")
            } else {
                print("No outputs left to consume")
            }
        }
    }

    func isTranscriptEmpty() -> Bool {
        let keychain = KeychainSwift()
        
        if let currentTranscripts = keychain.get("transcripts") {
            if let currentTranscriptsInt = Int(currentTranscripts), currentTranscriptsInt < maxTranscripts {
                return false
            } else {
                return true
            }
        } else {
            return false
        }
    }
    
    func isOutputEmpty() -> Bool {
        let keychain = KeychainSwift()
        if let currentOutputs = keychain.get("outputs") {
            if let currentOutputsInt = Int(currentOutputs), currentOutputsInt < maxOutputs {
                return false
            } else {
                return true
            }
        } else {
            return false
        }

    }
}
