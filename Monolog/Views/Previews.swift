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
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
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
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "folder")
                    .foregroundColor(.blue)
            }
            Text(name)
            Spacer()
        }.font(.body)
    }
    
}

struct OutputPreview: View {
    @ObservedObject var output: Output
    
    var body: some View {
        switch output.status {
        case .error:
             HStack{
                 Image(systemName: "exclamationmark.arrow.circlepath").foregroundColor(.red)
                ZStack {
                    Text("Error").foregroundColor(.gray).font(output.type == .Title ? .headline : .body)
                }
            }
        case .loading:
            HStack{
                ProgressView().scaleEffect(0.8, anchor: .center).padding(.trailing, 5)
                ZStack {
                    Text(output.content)
                        .font(.body).foregroundColor(.gray).font(output.type == .Title ? .headline : .body)
                }
            }
        case .completed:
            HStack{
                Text(output.content).font(output.type == .Title ? .headline : .body).lineLimit(output.type == .Title ? 2 : 4).truncationMode(.tail)
            }
        case .restricted:
             HStack{
                 Image(systemName: "exclamationmark.circle").foregroundColor(.red)
                ZStack {
                    Text("Upgrade to Transcribe").font(output.type == .Title ? .headline : .body).lineLimit(output.type == .Title ? nil : 4)
                }
            }
        }
    }
}
