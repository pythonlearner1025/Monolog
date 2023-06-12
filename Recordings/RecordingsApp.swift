//
//  RecordingsApp.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//

import SwiftUI


@main
struct RecordingsApp: App {
    @StateObject var folderNavigationModel = FolderNavigationModel()
    @StateObject var audioRecorder: AudioRecorderModel = AudioRecorderModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
               .environmentObject(folderNavigationModel)
               .environmentObject(audioRecorder)
        }
    }
}
