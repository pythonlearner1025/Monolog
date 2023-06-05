//
//  UserSettings.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//

import Foundation

extension UserDefaults {
    func storeSettings(_ settings: Settings, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(settings)
            set(data, forKey: key)
        } catch {
            print("Failed to store settings: \(error)")
        }
    }

    func getSettings(forKey key: String) -> Settings? {
        guard let data = data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            print("Failed to decode settings: \(error)")
            return nil
        }
    }
    
    func storeOutputSettings(_ settings: OutputSettings, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(settings)
            set(data, forKey: key)
        } catch {
            print("Failed to store output settings: \(error)")
        }
    }
    
    func getOutputSettings(forKey key: String) -> OutputSettings? {
        guard let data = data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(OutputSettings.self, from: data)
        } catch {
            print("Failed to decode outputsettings: \(error)")
            return nil
        }
    }
}
