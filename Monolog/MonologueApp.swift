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
    @StateObject var consumableModel: ConsumableModel = ConsumableModel()
    @StateObject var storeModel = StoreModel()
    var body: some Scene {
        WindowGroup {
            HomeView()
               .environmentObject(folderNavigationModel)
               .environmentObject(audioRecorder)
               .environmentObject(recordingsModel)
               .environmentObject(consumableModel)
               .environmentObject(storeModel)
               .onAppear(perform: {
                  if isNewLaunch {
                      let fileManager = FileManager.default
                      let recordingsFolder = Util.buildFolderURL("Recordings")
                      let recordingsContents = try! fileManager.contentsOfDirectory(at: recordingsFolder, includingPropertiesForKeys: nil)
                      let fileCount = recordingsContents.count == 0 ? recordingsContents.count : recordingsContents.count-1
                      let all = Folder(name: "Recordings", path: "Recordings", count: fileCount)
                      folderNavigationModel.addAllFolderView(all)
                      isNewLaunch = false
                  }
             })
        }
    }
}
