//
//  ContentView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all folders

import SwiftUI
/*
struct HomeView: View {
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true
    @AppStorage("isNewLaunch") var isNewLaunch: Bool = true
    //var isFirstLaunch = true
    @State private var showAllFirst = true
    @State private var folders: [RecordingFolder] = []
    @State private var showAlert = false
    @State private var newFolderName = ""

    private var section = ["Defaults", "User Created"]
    
    init() {
        print("== INIT ==")
        print(isFirstLaunch)
        print(isNewLaunch)
        if isFirstLaunch {
            setup()
            loadFolders()
            print(folders.count)
            isFirstLaunch = false
        }
    }
    
    var body: some View {
       
            NavigationStack {
                List{
                    Section(){
                        ForEach(folders.indices, id: \.self) { folderi in
                            if folders[folderi].name == "All" {
                                NavigationLink(destination: FolderView(folder: folders[folderi]), isActive: $isNewLaunch) {
                                    FolderInnerView(folder: folders[folderi])
                                }
                                .onAppear(perform: {
                                    loadFolder(folders[folderi], idx: folderi)
                                })
                                .deleteDisabled(true)
                            } else if folders[folderi].name == "Recently Deleted" {
                                NavigationLink(destination: FolderView(folder: folders[folderi])) {
                                    FolderInnerView(folder: folders[folderi])
                                }
                                .onAppear(perform: {
                                    loadFolder(folders[folderi], idx: folderi)
                                })
                                .deleteDisabled(true)
                            }
                        }
                    }
                    Section(header: Text("My Folders")){
                        ForEach(folders.indices, id: \.self) { folderi in
                            if folders[folderi].name != "All" && folders[folderi].name != "Recently Deleted" {
                                NavigationLink(destination: FolderView(folder: folders[folderi])) {
                                    FolderInnerView(folder: folders[folderi])
                                    }
                                .onAppear(perform: {
                                    loadFolder(folders[folderi], idx: folderi)
                                })
                                .deleteDisabled(false)
                            }
                               
                        }.onDelete{ indexSet in
                            indexSet.sorted(by: >).forEach{ i in
                                deleteFolder(targetFolder: folders[i])
                            }
                            folders.remove(atOffsets: indexSet)
                        }
                        }
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
                }
            .onAppear(perform: {
                loadFolders()
                }
            )
            .listStyle(.automatic)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification), perform: { output in
                    print("calling terminate")
                    isNewLaunch = true
                })
        
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
        let deletedFilesFolderPath =
            applicationSupportDirectory.appendingPathComponent("Recently Deleted")
        let deletedAudioFolderPath = deletedFilesFolderPath.appendingPathComponent("raw")
        
        // create "raw" folder in deletedFilesFolder
        do {
            try fileManager.createDirectory(at: allFilesFolderPath, withIntermediateDirectories: true, attributes: nil)
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
           let folderURLs = try fileManager.contentsOfDirectory(at: applicationSupportDirectory, includingPropertiesForKeys: nil)
           folders = folderURLs.compactMap { url -> RecordingFolder? in
               let folderName = url.lastPathComponent
               let folderPath = url.path
               do {
                   let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                   let itemCount = folderContents.count == 0 ? folderContents.count : folderContents.count-1
                   print("loaded folder \(url)")
                   return RecordingFolder(name: folderName, path: folderPath, count: itemCount)
               } catch {
                   print("An error occurred while counting items in \(folderName): \(error)")
                   return nil
               }
           }
       } catch {
           print("An error occurred while retrieving folder URLs: \(error)")
       }
    }
    
    func loadFolder(_ folder: RecordingFolder, idx: Int) {
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        
        do {
            let folderContents = try fileManager.contentsOfDirectory(atPath: folder.path)
            let itemCount = folderContents.count == 0 ? folderContents.count : folderContents.count-1
            folders[idx] = RecordingFolder(name: folder.name, path: folder.path, count: itemCount)
        } catch {
            print("error loading folder \(error)")
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
        do {
            try fileManager.createDirectory(at: newFolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("An error occurred while creating the 'All' directory: \(error)")
        }
        // Create a new Folder instance and add it to the 'folders' array
        let newFolder = RecordingFolder(name: title, path: newFolderPath.path, count: 0)
        folders.append(newFolder)
    }

}
*/

struct HomeView: View {
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true
    @AppStorage("isNewLaunch") var isNewLaunch: Bool = true
    @EnvironmentObject var folderNavigationModel: FolderNavigationModel

    //var isFirstLaunch = true
    @State private var showAllFirst = true
    @State private var folders: [RecordingFolder] = []
    @State private var showAlert = false
    @State private var newFolderName = ""
    private var section = ["Defaults", "User Created"]
    
    init() {
        print("== INIT ==")
        print(isFirstLaunch)
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
            }
            .onAppear(perform: {
                print("Loading folders")
                loadFolders()
            }
        )
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
        let deletedFilesFolderPath =
            applicationSupportDirectory.appendingPathComponent("Recently Deleted")
        let deletedAudioFolderPath = deletedFilesFolderPath.appendingPathComponent("raw")
        
        // create "raw" folder in deletedFilesFolder
        do {
            try fileManager.createDirectory(at: allFilesFolderPath, withIntermediateDirectories: true, attributes: nil)
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
           let folderURLs = try fileManager.contentsOfDirectory(at: applicationSupportDirectory, includingPropertiesForKeys: nil)
           folders = folderURLs.compactMap { url -> RecordingFolder? in
               let folderName = url.lastPathComponent
               let folderPath = url.path
               do {
                   let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                   let itemCount = folderContents.count == 0 ? folderContents.count : folderContents.count-1
                   print("loaded folder \(url)")
                   return RecordingFolder(name: folderName, path: folderPath, count: itemCount)
               } catch {
                   print("An error occurred while counting items in \(folderName): \(error)")
                   return nil
               }
           }
       } catch {
           print("An error occurred while retrieving folder URLs: \(error)")
       }
    }
    
    func loadFolder(_ folder: RecordingFolder) {
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        
        do {
            let folderContents = try fileManager.contentsOfDirectory(atPath: folder.path)
            let itemCount = folderContents.count == 0 ? folderContents.count : folderContents.count-1
            let folderidx = folders.firstIndex(where: {$0.id == folder.id})
            folders[folderidx!] = RecordingFolder(name: folder.name, path: folder.path, count: itemCount)
            
        } catch {
            print("error loading folder \(error)")
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
        do {
            try fileManager.createDirectory(at: newFolderPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("An error occurred while creating the 'All' directory: \(error)")
        }
        // Create a new Folder instance and add it to the 'folders' array
        let newFolder = RecordingFolder(name: title, path: newFolderPath.path, count: 0)
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
