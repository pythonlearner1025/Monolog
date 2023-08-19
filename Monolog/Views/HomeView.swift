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
    @State private var showAlert = false
    @State private var folders: [Folder] = []
    @State private var newFolderName = ""
    @State private var isSheetPresented = false
    @State private var folderToDelete: Folder?
    @State private var showNewFolderAlert = false
    @State private var showDeleteConfirmationAlert = false
    @State private var showFolderDeleteAlert = false
    @State private var showRecordingsDeleteAlert = false
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
                               }
                               .swipeActions(allowsFullSwipe: false){
                                   Button {
                                       if folder.name == "Recently Deleted" {
                                           folderToDelete = folder
                                           showAlert = true
                                           showDeleteConfirmationAlert = true
                                       } else {
                                           if outputsLoaded(folder) {
                                                deleteFolder(targetFolder: folder, deleteFolder: false)
                                               recordingsModel[folder.path].recordings = []
                                               loadFolders()
                                           } else {
                                             showAlert = true
                                             showRecordingsDeleteAlert = true
                                             folderToDelete = folder
                                           }
                                       }
                                   } label: {
                                       Text("Delete All Recordings")
                                   }
                                   .tint(.red)
                               }
                           }
                           .onDelete{indexSet in}
                       }
                       Section(header: Text("My Folders").font(.headline).bold()){
                           ForEach(myFolders.indices, id: \.self) {idx in
                                   NavigationLink(value: myFolders[idx]) {
                                       FolderPreview(myFolders[idx])
                                   }
                                   .swipeActions(allowsFullSwipe: false){
                                       Button(role: .destructive) {
                                           if outputsLoaded(myFolders[idx]) {
                                                deleteFolder(targetFolder: myFolders[idx])
                                                loadFolders()
                                           } else {                                             showAlert = true
                                              folderToDelete = myFolders[idx]
                                              showFolderDeleteAlert = true
                                           }
                                       } label: {
                                           Text("Delete Folder")
                                       }
                                       
                                       Button {
                                           if outputsLoaded(myFolders[idx]) {
                                                deleteFolder(targetFolder: myFolders[idx], deleteFolder: false)
                                               recordingsModel[myFolders[idx].path].recordings = []
                                               loadFolders()
                                           } else {
                                               showAlert = true
                                               folderToDelete = myFolders[idx]
                                               showRecordingsDeleteAlert = true
                                           }
                                           
                                       } label: {
                                           Text("Delete All Recordings")
                                       }
                                       .tint(.gray)
                                   }
                                }.onDelete{indexSet in}
                           }
                       }
                       .alert(isPresented: $showAlert) {
                           if showDeleteConfirmationAlert {
                                return Alert(title: Text("Warning"),
                                     message: Text("Are you sure you want to permanently delete all recordings?"),
                                     primaryButton: .destructive(Text("Delete")) {
                                   if folderToDelete != nil {
                                       for rec in recordingsModel[folderToDelete!.path].recordings {
                                           rec.audioPlayer.stopPlaying()
                                           rec.audioPlayer.isPlaying = false
                                       }
                                       permaDelete(folderToDelete!)
                                       recordingsModel[folderToDelete!.path].recordings = []
                                       loadFolders()
                                       folderToDelete = nil
                                       showDeleteConfirmationAlert = false
                                   }
                                   },
                                     secondaryButton: .default(Text("Cancel").bold(), action: {
                                       folderToDelete = nil
                                       showDeleteConfirmationAlert = false
                               })
                               )
                           } else if showFolderDeleteAlert {
                               return Alert(title: Text("Warning"),
                                    message: Text("Are you sure you want to delete this folder while some recordings are still loading?"),
                                    primaryButton: .destructive(Text("Delete")) {
                                  if folderToDelete != nil {
                                     audioRecorder.cancelSave()
                                      for rec in recordingsModel[folderToDelete!.path].recordings {
                                          rec.audioPlayer.stopPlaying()
                                          rec.audioPlayer.isPlaying = false
                                      }
                                      deleteFolder(targetFolder: folderToDelete!)
                                      recordingsModel[folderToDelete!.path].recordings = []
                                      loadFolders()
                                      folderToDelete = nil
                                      showFolderDeleteAlert = false
                                  }
                                  },
                                    secondaryButton: .default(Text("Cancel").bold(), action: {
                                      folderToDelete = nil
                                      showFolderDeleteAlert = false
                              })
                              )
                           } else {
                               return Alert(title: Text("Warning"),
                                            message: Text("Are you sure you want to delete all recordings in this folder while some recordings are still loading?"),
                                    primaryButton: .destructive(Text("Delete")) {
                                  if folderToDelete != nil {
                                      audioRecorder.cancelSave()
                                      for rec in recordingsModel[folderToDelete!.path].recordings  {
                                          rec.audioPlayer.stopPlaying()
                                          rec.audioPlayer.isPlaying = false
                                      }
                                      deleteFolder(targetFolder: folderToDelete!, deleteFolder: false)
                                      recordingsModel[folderToDelete!.path].recordings = []
                                      loadFolders()
                                      folderToDelete = nil
                                      showRecordingsDeleteAlert = false
                                  }
                                  },
                                    secondaryButton: .default(Text("Cancel").bold(), action: {
                                      folderToDelete = nil
                                      showRecordingsDeleteAlert = false
                              })
                              )
                           }
                       }
                        .onAppear(perform: {
                           loadFolders()
                        })
                       .navigationDestination(for: Folder.self){ folder in
                           FolderView(folder: folder)
                               .environmentObject(folderNavigationModel)
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
                           )
                       .toolbar {
                           ToolbarItem(placement: .bottomBar){
                                   Button(action: {
                                   }) {
                                       Text("")
                                   }
                           }
                           ToolbarItem(placement: .bottomBar){
                               Button(action: {
                                   showNewFolderAlert = true
                               }) {
                                   Image(systemName: "folder.badge.plus")
                               }
                               .alert("New Folder", isPresented: $showNewFolderAlert, actions: {
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
                   } //navstack
                } // zstack
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
         
    private var myFolders: [Folder] {
        return folders.filter {folder in
            folder.name != "Recordings" && folder.name != "Recently Deleted"
        }
    }
    
    private var defaultFolders: [Folder] {
        return folders.filter { folder in
            folder.name == "Recordings" || folder.name == "Recently Deleted"
        }.reversed()
    }

    private func firstSetup() {
        let settings = Settings(outputs: [.Title, .Transcript, .Summary], length: .short, format: .bullet, tone: .casual)
        let outputSettings = OutputSettings(length: .short, format: .bullet, tone: .casual, name: "", prompt: "")
        UserDefaults.standard.storeSettings(settings, forKey: "Settings")
        UserDefaults.standard.storeOutputSettings(outputSettings, forKey: "Output Settings")
        
        do {
            let fileManager = FileManager.default
            let recordingsFolderPath = Util.buildFolderURL("Recordings")
            let recordingsAudioFolderPath = recordingsFolderPath.appendingPathComponent("raw")
            let deletedFilesFolderPath = Util.buildFolderURL("Recently Deleted")
            let deletedAudioFolderPath = deletedFilesFolderPath.appendingPathComponent("raw")
            
            try fileManager.createDirectory(at: recordingsFolderPath,
                withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: recordingsAudioFolderPath, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: deletedFilesFolderPath,
                withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: deletedAudioFolderPath,
                withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("An error occurred while initiating directories: \(error)")
        }
        print("first setup complete")
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
    
    private func permaDelete(_ targetFolder: Folder){
        let fileManager = FileManager.default
        let targetFolderURL = Util.buildFolderURL(targetFolder.path)
        let targetFolderRawURL = targetFolderURL.appendingPathComponent("raw")
        do {
            let targetFolderContents = try fileManager.contentsOfDirectory(at: targetFolderURL, includingPropertiesForKeys: nil)
            let targetFolderRawContents = try fileManager.contentsOfDirectory(at: targetFolderRawURL, includingPropertiesForKeys: nil)

            for item in targetFolderContents {
                try fileManager.removeItem(at: item)
            }
            
            for item in targetFolderRawContents {
                try fileManager.removeItem(at: item)
            }
        } catch {
            print("Error perma deleting")
        }
    }
  
    private func deleteFolder(targetFolder: Folder, deleteFolder: Bool = true) {
        let delFolderName = "Recently Deleted"
        let fileManager = FileManager.default
        let targetFolderURL = Util.buildFolderURL(targetFolder.path)
        let targetFolderRawURL = targetFolderURL.appendingPathComponent("raw")
        let recentlyDeletedFolderPath = Util.buildFolderURL(delFolderName)
        let recentlyDeletedFolderRawPath = recentlyDeletedFolderPath.appendingPathComponent("raw")

        do {
            // Ensure "Recently Deleted" and its "raw" subfolder exist
            try ensureDirectoryExists(at: recentlyDeletedFolderPath)
            try ensureDirectoryExists(at: recentlyDeletedFolderRawPath)
            
            // Move each item to the 'Recently Deleted' folder
            let targetFolderRawContents = try fileManager.contentsOfDirectory(at: targetFolderRawURL, includingPropertiesForKeys: nil)
            for item in targetFolderRawContents {
                let oldLocation = targetFolderRawURL.appendingPathComponent(item.lastPathComponent)
                let newLocation = recentlyDeletedFolderRawPath.appendingPathComponent(item.lastPathComponent)
                try fileManager.moveItem(at: oldLocation, to: newLocation)
            }
            
            let targetFolderContents = try fileManager.contentsOfDirectory(at: targetFolderURL, includingPropertiesForKeys: nil)
            // sort recording file URI in ascending order, newest last
            let sortedFolderContents = targetFolderContents.sorted {
                let date1 = (try? fileManager.attributesOfItem(atPath: $0.path)[FileAttributeKey.creationDate] as? Date) ?? Date.distantPast
                let date2 = (try? fileManager.attributesOfItem(atPath: $1.path)[FileAttributeKey.creationDate] as? Date) ?? Date.distantPast
                return date1 < date2
            }
            var deleted = 0
            for item in sortedFolderContents {
                if item.lastPathComponent == "raw" {
                    continue
                }
                deleted += 1
                let oldLocation = targetFolderURL.appendingPathComponent(item.lastPathComponent)
                let newLocation = recentlyDeletedFolderPath.appendingPathComponent(item.lastPathComponent)
                
                // Check if the file already exists at the new location
                if !fileManager.fileExists(atPath: newLocation.path) {
                    try fileManager.moveItem(at: oldLocation, to: newLocation)
                    try fileManager.setAttributes([.creationDate: Date()], ofItemAtPath: newLocation.path)
                } else {
                    print("Item already exists at \(newLocation), not moving it.")
                }
            }
            // reset recording path
            for rec in recordingsModel[targetFolder.path].recordings {
                rec.folderPath = delFolderName
            }
            // update recordingsModel
            recordingsModel[delFolderName].recordings = recordingsModel[targetFolder.path].recordings + recordingsModel[delFolderName].recordings
            // Delete the target folder
            if deleteFolder {
                try fileManager.removeItem(at: targetFolderURL)
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
    
    private func ensureDirectoryExists(at url: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func outputsLoaded(_ folder: Folder) -> Bool {
        for recording in recordingsModel[folder.name].recordings {
            for out in recording.outputs.outputs {
                if out.status == .loading {
                    return false
                }
            }
        }
        return true
    }
    
}
