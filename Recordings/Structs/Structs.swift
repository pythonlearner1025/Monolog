//
//  Structs.swift
//  Recordings
//
//  Created by minjune Song on 5/25/23.
//

import Foundation
import UIKit
import SwiftUI


struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {}
}


struct Settings: Encodable, Decodable {
    var outputs: [OutputType]
    var length: LengthType
    var format: FormatType
    var tone: ToneType
}

struct OutputSettings: Encodable, Decodable {
    var length: LengthType
    var format: FormatType
    var tone: ToneType
    var name: String
    var prompt: String
    
    static var defaultSettings: OutputSettings {
        return OutputSettings(length: .short, format: .bullet, tone: .casual, name: "Default", prompt: "")
    }
}

struct Update {
    var type: OutputType
    var content: String
    var settings: OutputSettings
}

struct CameraButtonView: View {

    @State var recording = false
    var action: ((_ recording: Bool) -> Void)?

    var body: some View {

        ZStack {
            Circle()
                .stroke(lineWidth: 4)
                .foregroundColor(.white)
                .frame(width: 63, height: 63)
            
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

struct CameraButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {

            CameraButtonView(recording: false)
                .previewLayout(PreviewLayout.sizeThatFits)
                .previewDisplayName("not recording")
                .background(Color.gray)

            CameraButtonView(recording: true)
                .previewLayout(PreviewLayout.sizeThatFits)
                .previewDisplayName("recording")
                .background(Color.gray)

            ZStack {
                Image("turtlerock")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                HStack {
                    Spacer()
                    CameraButtonView()
                }
            }
        }
    }
}
/*
 all user default values
 - default outputs: summary, actions
 - length: short, medium, long
 - format: bullet point, paragraph
 - style: casual, professional
 */
