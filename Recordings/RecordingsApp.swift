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

    var body: some Scene {
        WindowGroup {
            HomeView()
               .environmentObject(folderNavigationModel)
               .environmentObject(audioRecorder)
               .onAppear(perform: {
                    if isNewLaunch {
                    let fileManager = FileManager.default
                    let allFolder = Util.buildFolderURL("All")
                    let allContents = try! fileManager.contentsOfDirectory(at: allFolder, includingPropertiesForKeys: nil)
                    let fileCount = allContents.count == 0 ? allContents.count : allContents.count-1
                    let all = RecordingFolder(name: "All", path: "All", count: fileCount)
                    folderNavigationModel.addAllFolderView(all)
                    isNewLaunch = false
                }
               })
        }
    }
}
