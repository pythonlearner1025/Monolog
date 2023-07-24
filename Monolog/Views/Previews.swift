//
//  FolderPreview.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import SwiftUI

struct FolderPreview: View {
    @ObservedObject var folder: Folder
    init (_ folder: Folder) {
        self.folder = folder
    }
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

struct MoveFolderPreview: View {
    var name: String
    init (_ name: String) {
        self.name = name
    }
    var body: some View {
        HStack{
            if name == "Recently Deleted" {
                Image(systemName: "trash")
            } else {
                Image(systemName: "folder")
            }
            Text(name)
            Spacer()
        }.font(.body)
    }
    
}

struct OutputPreview: View {
    @ObservedObject var output: Output
    var body: some View {
        if output.error {
            HStack{
                Image(systemName: "exclamationmark.arrow.circlepath")
                ZStack {
                    Text("Error").foregroundColor(.gray).font(output.type == .Title ? .headline : .body)
                }
            }
        } else if output.loading {
            // TODO: adjust spinner gap with title when output.type is Title
            HStack{
                ProgressView().scaleEffect(0.8, anchor: .center).padding(.trailing, 5)
                ZStack {
                    Text(output.content)
                        .font(.body).foregroundColor(.gray).font(output.type == .Title ? .headline : .body)
                }
            }
        } else {
            Text(output.content).font(output.type == .Title ? .headline : .body).lineLimit(output.type == .Title ? nil : 4).truncationMode(.tail)
        }
    }
}
