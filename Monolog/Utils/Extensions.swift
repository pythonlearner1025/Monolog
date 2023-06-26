//
//  Extensions.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//

import Foundation
import SwiftUI

extension AudioRecorderModel {
    func getFileDate(for file: URL) -> Date {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path) as [FileAttributeKey: Any],
            let creationDate = attributes[FileAttributeKey.creationDate] as? Date {
            return creationDate
        } else {
            return Date()
        }
    }

    func covertSecToMinAndHour(seconds : Int) -> String{
        
        let (_,m,s) = (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
        let sec : String = s < 10 ? "0\(s)" : "\(s)"
        return "\(m):\(sec)"
        
    }
}


extension Date
{
    func toString(dateFormat format: String ) -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
        
    }

}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

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
    
    var defaultOutputSettings: OutputSettings {
        return OutputSettings(length: .medium, format: .bullet, tone: .casual,  name: "Default Output", prompt: "")
    }
    
}
