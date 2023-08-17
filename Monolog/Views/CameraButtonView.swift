//
//  CameraButtonView.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import SwiftUI


struct CameraButtonView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var audioRecorder: AudioRecorderModel
    var action: ((_ recording: Bool) -> Void)?
    var body: some View {
        VStack{
            ZStack {
                Circle()
                    .stroke(lineWidth: 4)
                    .foregroundColor(colorScheme == .dark ? .white : .gray)
                    .frame(width: 65, height: 65)
                RoundedRectangle(cornerRadius: audioRecorder.isRecording ? 8 : self.innerCircleWidth / 2)
                    .foregroundColor(.red)
                    .frame(width: self.innerCircleWidth, height: self.innerCircleWidth)
            }
            .animation(.linear(duration: 0.2))
            .padding(.top, 20)
            .padding(.bottom, 10)
            .onTapGesture {
                withAnimation {
                    self.action?(self.audioRecorder.isRecording)
                }
            }
        }
    }

    var innerCircleWidth: CGFloat {
        self.audioRecorder.isRecording ? 32 : 55
    }
}
