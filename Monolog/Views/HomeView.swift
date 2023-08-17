//
//  ContentView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all folders

import SwiftUI

struct HomeView: View {
    @AppStorage("isNewLaunch") var isNewLaunch: Bool = true
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true
    @EnvironmentObject var folderNavigationModel: FolderNavigationModel
    @EnvironmentObject var audioRecorder: AudioRecorderModel
    @EnvironmentObject var recordingsModel: RecordingsModel
    @EnvironmentObject var consumableModel: ConsumableModel
    @EnvironmentObject var storeModel: StoreModel
    @State private var folders: [Folder] = []
    @State private var showAlert = false
    @State private var newFolderName = ""
    @State private var isSheetPresented = false
    private var section = ["Defaults", "User Created"]
    
    init() {
        if isFirstLaunch {
            firstSetup()
            loadFolders()
            isSheetPresented = true
            isFirstLaunch = false
        }
      }
    
    var body: some View {
           ZStack{
               NavigationStack(path: $folderNavigationModel.presentedItems) {
                   List{
                       Section{
                           ForEach(defaultFolders) {folder in
                               NavigationLink(value: folder) {
                                   FolderPreview(folder)
                               }.deleteDisabled(true)
                           }
                       }
                       Section(header: Text("My Folders").font(.headline).bold()){
                           ForEach(folders) {folder in
                               if(folder.name != "Recordings" && folder.name != "Recently Deleted"){
                                   NavigationLink(value: folder) {
                                       FolderPreview(folder)
                                   }
                               }
                           }.onDelete{indexSet in
                               indexSet.sorted(by:>).forEach{i in deleteFolder(targetFolder: folders[i])
                               }
                               folders.remove(atOffsets: indexSet)
                           }
                       }
                   }
                    .onAppear(perform: {
                       loadFolders()
                    })
                   .navigationDestination(for: Folder.self){ folder in
                       FolderView(folder: folder)
                           .environmentObject(audioRecorder)
                           .environmentObject(recordingsModel)
                           .environmentObject(consumableModel)
                   }
                   .navigationDestination(for: Recording.self) { recording  in
                       RecordingView(recording: recording, outputs: recording.outputs)
                           .environmentObject(storeModel)
                           .environmentObject(consumableModel)
                   }
                   .navigationTitle("Folders")
                   .navigationBarItems(trailing:
                       EditButton()
                       ).toolbar {
                       ToolbarItem(placement: .bottomBar){
                               Button(action: {
                               }) {
                                   Text("")
                               }
                       }
                       ToolbarItem(placement: .bottomBar){
                               Button(action: {
                                   showAlert = true
                               }) {
                                   Image(systemName: "folder.badge.plus")
                               }
                               .alert("New Folder", isPresented: $showAlert, actions: {
                                   TextField("", text: $newFolderName)
                                   Button("Create", action: {
                                       createFolder(title: newFolderName)
                                       newFolderName=""
                                   }
                                   )
                                   Button("Cancel", role: .cancel, action: {})
                               })
                           }
                       }
               }
               .onChange(of: folderNavigationModel.presentedItems) {newVal in
                    if folderNavigationModel.presentedItems.count == 0 {
                        loadFolders()
                    }
                }
               .listStyle(.automatic)
               .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification), perform: { output in
                       isNewLaunch = true
                   })
               .sheet(isPresented: $isSheetPresented, onDismiss: {}) {
                    Text("Sheet Content")
                }
              
           }
         }
    
    private var defaultFolders: [Folder] {
        return folders.filter { folder in
            folder.name == "Recordings" || folder.name == "Recently Deleted"
        }.reversed()
    }

    private func firstSetup() {
        // init default settings
        let settings = Settings(outputs: [.Title, .Transcript, .Summary], length: .short, format: .bullet, tone: .casual)
        let outputSettings = OutputSettings(length: .short, format: .bullet, tone: .casual, name: "", prompt: "")
        UserDefaults.standard.storeSettings(settings, forKey: "Settings")
        UserDefaults.standard.storeOutputSettings(outputSettings, forKey: "Output Settings")
        
        
        // init default folders
        do {
            let fileManager = FileManager.default
            let applicationSupportDirectory = Util.root()
            let recordingsFolderPath = applicationSupportDirectory.appendingPathComponent("Recordings")
            let recordingsAudioFolderPath = recordingsFolderPath.appendingPathComponent("raw")
            let deletedFilesFolderPath =
                applicationSupportDirectory.appendingPathComponent("Recently Deleted")
            let deletedAudioFolderPath = deletedFilesFolderPath.appendingPathComponent("raw")
            try fileManager.createDirectory(at: recordingsFolderPath, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: recordingsAudioFolderPath, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: deletedFilesFolderPath,
                                            withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: deletedAudioFolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("An error occurred while creating the 'Recordings' directory: \(error)")
        }
    }
    
    private func loadFolders() {
        let fileManager = FileManager.default
        let applicationSupportDirectory = Util.root()
        do {
            let folderURLs = try! fileManager.contentsOfDirectory(at: applicationSupportDirectory, includingPropertiesForKeys: nil)
            folders = folderURLs.compactMap { url -> Folder? in
                let folderName = url.lastPathComponent
                let folderPath = url.path
                do {
                    let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                    let itemCount = folderContents.count == 0 ? folderContents.count : folderContents.count-1
                    return Folder(name: folderName, path: folderName, count: itemCount)
                } catch {
                    print("An error occurred while counting items in \(folderName): \(error)")
                    return nil
                }
            }
        }
    }
    
    // TODO: check this works
    private func deleteFolder(targetFolder: Folder) {
        let fileManager = FileManager.default
        let applicationSupportDirectory = Util.root()
        let targetFolderURL = applicationSupportDirectory.appendingPathComponent( targetFolder.path)
        let targetFolderRawURL = targetFolderURL.appendingPathComponent("raw")
        let recentlyDeletedFolderPath = applicationSupportDirectory.appendingPathComponent("Recently Deleted")
        let recentlyDeletedFolderRawPath = recentlyDeletedFolderPath.appendingPathComponent("raw")

        do {
            // Move each item to the 'Recently Deleted' folder
            let targetFolderRawContents = try fileManager.contentsOfDirectory(at: targetFolderRawURL, includingPropertiesForKeys: nil)
            for item in targetFolderRawContents {
                let oldLocation = targetFolderRawURL.appendingPathComponent(item.lastPathComponent)
                let newLocation = recentlyDeletedFolderRawPath.appendingPathComponent(item.lastPathComponent)
                    try fileManager.moveItem(at: oldLocation, to: newLocation)
            }
            
            // Get the contents of the target folder
            let targetFolderContents = try fileManager.contentsOfDirectory(at: targetFolderURL, includingPropertiesForKeys: nil)
            var deleted = 0
            for item in targetFolderContents {
                if item.lastPathComponent == "raw" {
                    continue
                }
                deleted += 1
                let oldLocation = targetFolderURL.appendingPathComponent(item.lastPathComponent)
                let newLocation = recentlyDeletedFolderPath.appendingPathComponent(item.lastPathComponent)
                
                // Check if the file already exists at the new location
                if !fileManager.fileExists(atPath: newLocation.path) {
                    try fileManager.moveItem(at: oldLocation, to: newLocation)
                } else {
                    print("Item already exists at \(newLocation), not moving it.")
                }
            }
            // Delete the target folder
            try fileManager.removeItem(at: targetFolderURL)
            if let idx = folders.firstIndex(where: {$0.name == "Recently Deleted"}) {
                folders[idx].count += deleted
            }
        } catch {
            print("An error occurred while deleting folder \(targetFolder.name): \(error)")
        }
    }
    
    private func createFolder(title: String) {
        let fileManager = FileManager.default
        let applicationSupportDirectory = Util.root()
        let newFolderPath = applicationSupportDirectory.appendingPathComponent(title)
        let newFolderRawPath = newFolderPath.appendingPathComponent("raw")
        do {
            try fileManager.createDirectory(at: newFolderPath, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: newFolderRawPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("An error occurred while creating the 'Recordings' directory: \(error)")
        }
        // Create a new Folder instance and add it to the 'folders' array
        let newFolder = Folder(name: title, path: newFolderPath.lastPathComponent, count: 0)
        withAnimation{
            folders.append(newFolder)
        }
    }
}
