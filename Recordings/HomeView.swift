//
//  ContentView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all folders

import SwiftUI

struct HomeView: View {
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true
    @AppStorage("isNewLaunch") var isNewLaunch: Bool = true
    @EnvironmentObject var folderNavigationModel: FolderNavigationModel
    @EnvironmentObject var audioRecorder: AudioRecorderModel
    //var isFirstLaunch = true
    @State private var showAllFirst = true
    @State private var folders: [RecordingFolder] = []
    @State private var showAlert = false
    @State private var newFolderName = ""
    private var section = ["Defaults", "User Created"]
    
    init() {
        print("== INIT ==")
        print(isNewLaunch)
        if isFirstLaunch {
            setup()
            loadFolders()
            print(folders.count)
            isFirstLaunch = false
        }
        
      }
    
    var body: some View {
           ZStack{
               NavigationStack(path: $folderNavigationModel.presentedItems) {
                   List (folders){ folder in
                       NavigationLink(value: folder) {
                           FolderInnerView(folder: folder)
                           }
                           .deleteDisabled(true)
                   }
                   .navigationDestination(for: RecordingFolder.self){ folder in
                       FolderView(folder: folder)
                           .environmentObject(audioRecorder)
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
                                   TextField("New folder name", text: $newFolderName)
                                   Button("Create", action: {
                                       createFolder(title: newFolderName)
                                       newFolderName=""
                                   }
                                   )
                                   Button("Cancel", role: .cancel, action: {})
                               })
                           }
                       }
                     .onAppear(perform: {
                       print("Loading folders")
                       loadFolders()
                   })
               }
           .listStyle(.automatic)
           .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification), perform: { output in
                   print("calling terminate")
                   isNewLaunch = true
               })
           }
         }



    func setup() {
        //default settings
        let settings = Settings(outputs: [.Title, .Transcript, .Summary, .Action], length: .short, format: .bullet, tone: .casual)
        let outputSettings = OutputSettings(length: .short, format: .bullet, tone: .casual,name: "", prompt: "")
        UserDefaults.standard.storeSettings(settings, forKey: "Settings")
        UserDefaults.standard.storeOutputSettings(outputSettings, forKey: "Output Settings")
        // default folders
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let allFilesFolderPath = applicationSupportDirectory.appendingPathComponent("All")
        let allFilesAudioFolderPath = allFilesFolderPath.appendingPathComponent("raw")
        let deletedFilesFolderPath =
            applicationSupportDirectory.appendingPathComponent("Recently Deleted")
        let deletedAudioFolderPath = deletedFilesFolderPath.appendingPathComponent("raw")
        
        // create "raw" folder in deletedFilesFolder
        do {
            try fileManager.createDirectory(at: allFilesFolderPath, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: allFilesAudioFolderPath, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: deletedFilesFolderPath,
                                            withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: deletedAudioFolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("An error occurred while creating the 'All' directory: \(error)")
        }
    }
    

    
    func loadFolders() {
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        
        do {
            let folderURLs = try! fileManager.contentsOfDirectory(at: applicationSupportDirectory, includingPropertiesForKeys: nil)
            var allCount = 0
            folders = folderURLs.compactMap { url -> RecordingFolder? in
                let folderName = url.lastPathComponent
                let folderPath = url.path
                do {
                    print("loaded folder \(url.path)")
                    let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                    let itemCount = folderContents.count == 0 ? folderContents.count : folderContents.count-1
                    if (folderName != "Recently Deleted") {
                        allCount += itemCount
                    }
                    if (folderName != "All") {
                         return RecordingFolder(name: folderName, path: folderName, count: itemCount)
                    } else {
                        return nil
                    }
                } catch {
                    print("An error occurred while counting items in \(folderName): \(error)")
                    return nil
                }
            }
            folders.append(RecordingFolder(name: "All", path: "All", count: allCount))
        }
    }
    
    // TODO: check this works
    func deleteFolder(targetFolder: RecordingFolder) {
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let recentlyDeletedFolderPath = applicationSupportDirectory.appendingPathComponent("Recently Deleted")

        do {
            // Get the contents of the target folder
            let targetFolderContents = try fileManager.contentsOfDirectory(atPath: targetFolder.path)
            
            // Move each item to the 'Recently Deleted' folder

            for item in targetFolderContents {
                let itemPath = URL(fileURLWithPath: targetFolder.path).appendingPathComponent(item)
                let newLocation = recentlyDeletedFolderPath.appendingPathComponent(item)
                
                // Check if the file already exists at the new location
                if !fileManager.fileExists(atPath: newLocation.path) {
                    try fileManager.moveItem(at: itemPath, to: newLocation)
                } else {
                    print("Item already exists at \(newLocation), not moving it.")
                }
            }

            // Delete the target folder
            try fileManager.removeItem(atPath: targetFolder.path)
        } catch {
            print("An error occurred while deleting folder \(targetFolder.name): \(error)")
        }
    }
    
    func createFolder(title: String) {
        print(title)
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let newFolderPath = applicationSupportDirectory.appendingPathComponent(title)
        let newAudioFolderPath = newFolderPath.appendingPathComponent("raw")
        do {
            try fileManager.createDirectory(at: newFolderPath, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: newAudioFolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("An error occurred while creating the 'All' directory: \(error)")
        }
        // Create a new Folder instance and add it to the 'folders' array
        let newFolder = RecordingFolder(name: title, path: newFolderPath.lastPathComponent, count: 0)
        folders.append(newFolder)
    }

}

struct FolderInnerView: View {
    @ObservedObject var folder: RecordingFolder
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack{
                if folder.name == "Recently Deleted" {
                    Image(systemName: "trash")
                } else {
                    Image(systemName: "folder")
                }
                Text(folder.name)
            }.font(.body)
            Text("\(folder.count) items")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
