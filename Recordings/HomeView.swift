//
//  ContentView.swift
//  Recordings
//
//  Created by minjune Song on 5/24/23.
//
// view of all folders


import SwiftUI

struct Folder: Identifiable {
    let id = UUID()
    var name: String
    var path: String
    var count: Int
}

struct HomeView: View {
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true

    init() {
        if isFirstLaunch {
            setup()
            isFirstLaunch = false
        }
    }

    @State private var folders: [Folder] = []
    @State private var showAlert = false
    @State private var newFolderName = ""
    private var section = ["Defaults", "User Created"]
    
    var body: some View {
        if isFirstLaunch {
            
        }
        
        else{
            NavigationStack {
                List{
                    Section(header: Text("Defaults")){
                        ForEach(folders.indices, id: \.self) { folderi in
                            if folders[folderi].name == "All" || folders[folderi].name == "Recently Deleted" {
                                NavigationLink(destination: FolderView(folder: folders[folderi])) {
                                    VStack(alignment: .leading) {
                                        HStack{
                                            Image(systemName: "folder")
                                            Text(folders[folderi].name)
                                        }.font(.body)
                                        Text("\(folders[folderi].count) items")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                    Section(header: Text("User-Created")){
                        ForEach(folders.indices, id: \.self) { folderi in
                            if folders[folderi].name != "All" || folders[folderi].name != "Recently Deleted" {
                                    NavigationLink(destination: FolderView(folder: folders[folderi])) {
                                        VStack(alignment: .leading) {
                                            HStack{
                                                Image(systemName: "folder")
                                                Text(folders[folderi].name)
                                            }.font(.body)
                                            Text("\(folders[folderi].count) items")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    }.navigationTitle("Folders")
            .navigationBarItems(trailing:
            HStack{
                Button(action:{
                    
                }) {
                    Image(systemName: "folder.badge.minus")
                }
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
                
            })
                
                }.onAppear(perform: loadFolders)


                
                
            }
        }
    

    
    func setup() {
        //default settings
        let defaultSettings = Settings(outputs: [.Transcript, .Summary, .Action], length: .medium, format: .bullet, style: .casual)
        UserDefaults.standard.store(defaultSettings, forKey: "Settings")
        // default folders
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let allFilesFolderPath = applicationSupportDirectory.appendingPathComponent("All")
        let deletedFilesFolderPath =
            applicationSupportDirectory.appendingPathComponent("Recently Deleted")
        do {
            try fileManager.createDirectory(at: allFilesFolderPath, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: deletedFilesFolderPath,
                                            withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("An error occurred while creating the 'All' directory: \(error)")
        }
    }
    
    func loadFolders() {
        let fileManager = FileManager.default
        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        
        do {
           let folderURLs = try fileManager.contentsOfDirectory(at: applicationSupportDirectory, includingPropertiesForKeys: nil)
           folders = folderURLs.compactMap { url -> Folder? in
               let folderName = url.lastPathComponent
               let folderPath = url.path
               do {
                   let folderContents = try fileManager.contentsOfDirectory(atPath: folderPath)
                   let itemCount = folderContents.count == 0 ? folderContents.count : folderContents.count-1
                   return Folder(name: folderName, path: folderPath, count: itemCount)
               } catch {
                   print("An error occurred while counting items in \(folderName): \(error)")
                   return nil
               }
           }
       } catch {
           print("An error occurred while retrieving folder URLs: \(error)")
       }
    }
    
    func deleteFolder(targetFolder: Folder) {
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
                try fileManager.moveItem(at: itemPath, to: newLocation)
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
        let newFolder = Folder(name: title, path: newFolderPath.path, count: 0)
        folders.append(newFolder)
    }

}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
