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
    //var isFirstLaunch = true
    @State private var showAllFirst = true
    @State private var folders: [RecordingFolder] = []
    @State private var showAlert = false
    @State private var newFolderName = ""
    private var section = ["Defaults", "User Created"]
    @State private var path = NavigationPath()
    var temptest: [Int] = [0,1,2,3,4,5]
    
    init() {
        if isFirstLaunch {
            setup()
//            loadFolders()
//            print(folders.count)
            isFirstLaunch = false
        }
    }
    
    var body: some View {
        //        if false {
        //            VStack{List{
        //                FolderView(folder: folders[0])
        //            }}.onAppear(perform: loadFolders)
        //        }
        
        //        else{
        NavigationStack(path: $path) {
            List{
                Section(){
                    ForEach(folders, id: \.name) { folderi in
//                        if folderi.name == "All" || folderi.name == "Recently Deleted" {
                            //                                NavigationLink(destination: FolderView(folder: folderi)) {
                            //                                    FolderInnerView(folder: folderi)
                            //                                }
                            NavigationLink(value: folderi){
                                FolderInnerView(folder: folderi)
                            }
                            //                                .onAppear(perform: {
                            //                                    loadFolder(folders[folderi], idx: folderi)
                            //                                })
                            .deleteDisabled(true)
//                        }
                    }
                }
                Section(){
                    ForEach(temptest, id: \.self){val in
                        NavigationLink(value: val){
                            Text("\(val)")
                        }
                    }
                }
                
                //                    Section(header: Text("My Folders")){
                //                        ForEach(folders.indices, id: \.self) { folderi in
                //                            if folders[folderi].name != "All" && folders[folderi].name != "Recently Deleted" {
                //                                NavigationLink(destination: FolderView(folder: folders[folderi])) {
                //                                    FolderInnerView(folder: folders[folderi])
                //                                    }
                //                                .onAppear(perform: {
                //                                    loadFolder(folders[folderi], idx: folderi)
                //                                })
                //                                .deleteDisabled(false)
                //                            }
                //
                //                        }.onDelete{ indexSet in
                //                            indexSet.sorted(by: >).forEach{ i in
                //                                deleteFolder(targetFolder: folders[i])
                //                            }
                //                            folders.remove(atOffsets: indexSet)
                //                        }
                //                        }
            }.navigationDestination(for: RecordingFolder.self){index in FolderView(folder: index)
            }.navigationDestination(for: Int.self){index in
                Text("\(index)")
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
        .onAppear{
            loadFolders()
        }
        .listStyle(.automatic)
        
        //            }
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
