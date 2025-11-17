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
    
    // 用于保存加载出来的模板（可变，所以用 @State）
    @State private var templates: [TemplateKey: TemplateDescriptor] = [:]
    
    // 最新一次识别出来的 FEN（只含棋子布局部分）
    @State private var latestFEN: String? = nil
    
    // 模板加载器本身可以是常量
    private let loader = DefaultTemplateLoader()
    
    // 目标网页
    private let url = URL(string: "https://www.chesskid.com/home")!

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 底层：WebView，自动填满整个窗口
            WebView(url: url)
            
            // 上层：左侧区域（棋盘预览 + 控制面板），整体宽度约 300
            VStack(alignment: .leading, spacing: 0) {
                // 1️⃣ 棋盘预览：ReviewBoardView，固定 296x296
                if let fen = latestFEN, !templates.isEmpty {
                    ReviewBoardView(
                        fenPlacement: fen,
                        templates: templates
                    )
                    .frame(width: 296, height: 296)
                    .padding(.top, 8)
                    .padding(.leading, 4)
                }
                
                // 2️⃣ 左侧控制面板
                NewLeftPanelView(
                    current: $current,
                    onBegin: handleBeginTapped,
                    onNext: handleNextStepTapped
                )
            }
            .frame(width: 300)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        .onAppear {
            goFullScreenAndUpdateResolution()
        }
    }

    // MARK: - Buttons

    private func handleBeginTapped() {
        current = 1
        latestFEN = nil      // 清掉之前的预览
        print("▶️ Begin tapped, current = \(current)")

        guard let res = resolution else {
            print("⚠️ resolution is nil, nothing to delete")
            return
        }

        deleteContentsUnderChessAppResolutionFolder(resolutionFolderName: res)
    }
    
    private func handleNextStepTapped() {
        current += 1
        print("⏭ Next step tapped, current = \(current)")

        Task {
            // 1️⃣ 截屏并裁剪棋盘（Board/<current>.png）
            let result = await captureScreenShot(current: current, templates: templates)
            switch result {
            case .failure(let err):
                print("❌ captureScreenShot failed: \(err)")
                return
            case .success:
                break
            }
            
            // 2️⃣ 截图成功后，用 Board 图 + 模板生成 FEN，并更新到 UI
            guard let res = resolution else {
                print("⚠️ handleNextStepTapped: resolution is nil, cannot generate FEN")
                return
            }
            
            let fenResult = generateFENFromBoard(
                solution: res,
                current: current,
                templates: templates
            )
            
            switch fenResult {
            case .success(let fenPlacement):
                print("✅ Final FEN (UI) = \(fenPlacement)")
                // 更新到 @State，用于 ReviewBoardView 预览
                self.latestFEN = fenPlacement
            case .failure(let error):
                print("❌ Failed to generate FEN in handleNextStepTapped: \(error)")
                self.latestFEN = nil
            }
        }
    }

    // MARK: - Full screen & resolution

    private func goFullScreenAndUpdateResolution() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let window = NSApp.windows.first else { return }

            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.resolution = getScreenResolution()
                self.initLoader()        // 分辨率出来后再加载模板
            }
        }
    }

    // MARK: - Load templates

    private func initLoader() {
        guard var res = resolution else {
            print("⚠️ init Loader: resolution is nil")
            return
        }
        
        guard let templatesFolder = Bundle.main.resourceURL else {
            print("❌ init Loader: cannot find bundle resourceURL")
            return
        }

        // 如果你担心阻塞主线程，可以放到后台队列
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loaded = try self.loader.loadTemplates(
                    from: templatesFolder,
                    resolutionSuffix: res
                )
                DispatchQueue.main.async {
                    self.templates = loaded
                    print("✅ Loaded \(loaded.count) templates for resolution \(res)")
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ Failed to load templates: \(error)")
                }
            }
        }
    }

    // MARK: - Delete folder contents (保持原样)

    private func deleteContentsUnderChessAppResolutionFolder(resolutionFolderName: String) {
        let fm = FileManager.default

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
