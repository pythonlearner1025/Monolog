//
//  RecordingsApp.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//

import SwiftUI


@main
struct RecordingsApp: App {
    @AppStorage("isNewLaunch") var isNewLaunch: Bool = true
    @StateObject var folderNavigationModel = FolderNavigationModel()
    @StateObject var audioRecorder: AudioRecorderModel = AudioRecorderModel()
    @StateObject var recordingsModel: RecordingsModel = RecordingsModel()
    var body: some Scene {
        WindowGroup {
            HomeView()
               .environmentObject(folderNavigationModel)
               .environmentObject(audioRecorder)
               .environmentObject(recordingsModel)
        }
    }
}
