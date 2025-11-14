//
//  WindowSizeReader.swift
//  ChessApp
//
//  Created by stone on 2025/11/14.
//


import CoreGraphics
import Vision
import SwiftUI
import AppKit

/// 读取当前窗口的 content size，并通过 @Binding 回传到 SwiftUI
struct WindowSizeReader: NSViewRepresentable {
    @Binding var size: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        // 初始时读一次
        DispatchQueue.main.async {
            if let window = view.window {
                size = window.contentLayoutRect.size
            }
        }

        // 监听窗口尺寸变化
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main
        ) { [weak view] notif in
            guard
                let win = notif.object as? NSWindow,
                let v = view,
                win == v.window
            else { return }

            size = win.contentLayoutRect.size
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 这里一般不需要做什么
    }
}
