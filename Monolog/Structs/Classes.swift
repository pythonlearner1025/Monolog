//
//  Classes.swift
//  Recordings
//
//  Created by minjune Song on 6/3/23.
//

import Foundation
import SwiftUI
import Combine
import UIKit


class KeyboardResponder: ObservableObject {
    @Published var currentHeight: CGFloat = 0

    var keyboardShow: AnyCancellable?
    var keyboardHide: AnyCancellable?

    init() {
        keyboardShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map {
                let height = ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
                print("Keyboard will show, height: \(height)")
                return height
            }
            .assign(to: \.currentHeight, on: self)
        
        keyboardHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in
                print("Keyboard will hide")
                return 0
            }
            .assign(to: \.currentHeight, on: self)
    }
}

