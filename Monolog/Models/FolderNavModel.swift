//
//  FolderNavModel.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import SwiftUI

class FolderNavigationModel: ObservableObject {
    @Published var presentedItems: NavigationPath = NavigationPath()
    
    func addAllFolderView(_ folder: Folder) {
        presentedItems.append(folder)
    }
}
