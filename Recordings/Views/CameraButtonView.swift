//
//  CameraButtonView.swift
//  Recordings
//
//  Created by minjune Song on 6/19/23.
//

import SwiftUI

struct CameraButtonView: View {
    @State var recording = false
    var action: ((_ recording: Bool) -> Void)?
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 4)
                .foregroundColor(.white)
                .frame(width: 65, height: 65)
            
            RoundedRectangle(cornerRadius: recording ? 8 : self.innerCircleWidth / 2)
                .foregroundColor(.red)
                .frame(width: self.innerCircleWidth, height: self.innerCircleWidth)

        }
        .animation(.linear(duration: 0.2))
        .padding(.top, 30)
        .padding(.bottom, 20)
        .onTapGesture {
            withAnimation {
                self.action?(self.recording)
                self.recording.toggle()
            }
        }
    }

    var innerCircleWidth: CGFloat {
        self.recording ? 32 : 55
    }
}
