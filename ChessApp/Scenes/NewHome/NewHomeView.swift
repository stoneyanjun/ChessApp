//
//  NewHomeView.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import SwiftUI
import WebKit
import AppKit

struct NewHomeView: View {
    // 当前屏幕分辨率字符串，例如 "3840_2160"
    @State private var resolution: String? = nil
    @State private var current: Int = 0

    // 目标网页
    private let url = URL(string: "https://www.chesskid.com/home")!

    var body: some View {
        ZStack(alignment: .leading) {
            // 底层：WebView，自动填满整个窗口
            WebView(url: url)

            // 上层：左侧面板，固定宽度 200，竖直方向顶对齐并拉满
            NewLeftPanelView(
                onBegin: handleBeginTapped,
                onNext: handleNextStepTapped
            )
            .frame(width: 200)
            .frame(maxHeight: .infinity, alignment: .top) // 从上到下
        }
        // 关键：让整个根视图进入同一个坐标系，贴满窗口（包含标题栏区域）
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()   // WebView 和 LeftPanel 共用同一套 safe area 设置
        .onAppear {
            goFullScreenAndUpdateResolution()
        }
    }

    /// Begin 按钮点击逻辑
    private func handleBeginTapped() {
        // 1. Set current = 1
        current = 1
        print("▶️ Begin tapped, current = \(current)")

        // 2. 如果 resolution 有值，删除 Documents/ChessApp/<resolution> 下所有内容
        guard let res = resolution else {
            print("⚠️ resolution is nil, nothing to delete")
            return
        }

        deleteContentsUnderChessAppResolutionFolder(resolutionFolderName: res)
    }
    
    /// Next step 按钮点击逻辑
    private func handleNextStepTapped() {
        // 1. current += 1
        current += 1
        print("⏭ Next step tapped, current = \(current)")

        // 2. 调用 captureScreenShot(current: current)
        //    假设 captureScreenShot 是 async，如果是同步函数也没问题
        Task {
            await captureScreenShot(current: current)
        }
    }

    /// 启动后自动进入全屏，并在进入全屏后获取屏幕分辨率
    private func goFullScreenAndUpdateResolution() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let window = NSApp.windows.first else { return }

            // 先切到全屏
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }

            // 再稍微等一下，让系统完成全屏动画后再取分辨率
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.resolution = getScreenResolution()
            }
        }
    }

    /// 删除 Documents/ChessApp/<resolution> 目录下的所有文件和子目录（保留该目录本身）
    private func deleteContentsUnderChessAppResolutionFolder(resolutionFolderName: String) {
        let fm = FileManager.default

        // 获取 Documents 目录
        guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Cannot locate Documents directory")
            return
        }

        let folderURL = docsURL
            .appendingPathComponent("ChessApp")
            .appendingPathComponent(resolutionFolderName)

        let folderPath = folderURL.path
        print("🗂 Target folder to clean: \(folderPath)")

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: folderPath, isDirectory: &isDir), isDir.boolValue else {
            print("⚠️ Folder does not exist or is not a directory")
            return
        }

        do {
            let items = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [])
            if items.isEmpty {
                print("ℹ️ Folder is already empty")
                return
            }

            for url in items {
                do {
                    try fm.removeItem(at: url)
                    print("🗑 Deleted: \(url.path)")
                } catch {
                    print("❌ Failed to delete \(url.path): \(error)")
                }
            }

            print("✅ Finished cleaning folder: \(folderPath)")
        } catch {
            print("❌ Failed to list contents of folder \(folderPath): \(error)")
        }
    }
}
