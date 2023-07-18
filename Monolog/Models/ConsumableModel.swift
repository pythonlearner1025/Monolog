//
//  ConsumableModel.swift
//  Monolog
//
//  Created by minjune Song on 6/26/23.
//

import Foundation
import SwiftUI

class UseTranscriptModel {
    private let maxTranscripts: Int = 20
    
    init {
        let keychain = KeyChainSwift()
        
        if keychain.get("isFirstLaunch") == nil {
            keychain.set("0", forKey: "transcripts")
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

    func isEmpty() -> Int {
        let keychain = KeychainSwift()

        if let currentTranscripts = Int(keychain.get("transcripts")) {
           return currentTranscripts < maxTranscripts
        } else {
            return false
        }
    }
}


