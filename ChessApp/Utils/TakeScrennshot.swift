//
//  TakeScrennshot.swift
//  ChessApp
//
//  Created by stone on 2025/11/15.
//


import Foundation
import ComposableArchitecture
import AppKit
import CoreGraphics
import ScreenCaptureKit
import Vision

@MainActor
func captureScreenShot(current: Int, templates: [TemplateKey: TemplateDescriptor]) async -> Result<Data, CaptureError> {
    do {
        // 1️⃣ 调用你之前的 captureFullScreenCGImage()
        let (imageOpt, resolutionRaw) = try await finialCaptureFullScreen()
        
        guard let image = imageOpt else {
            print("❌ captureFullScreenCGImage returned nil image")
            return .failure(.noImage)
        }
        
        // 清理分辨率字符串，作为文件夹名和后续模板 / FEN 的 resolution 标识
        let resolutionFolderName = resolutionRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalResolution = resolutionFolderName.isEmpty ? "UnknownResolution" : resolutionFolderName
        
        // 2️⃣ 定位 ~/Documents
        guard let docsURL = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask).first else {
            print("❌ Cannot locate Documents folder")
            return .failure(.documentsNotFound)
        }
        
        // 3️⃣ 目标目录：~/Documents/ChessApp/<resolution>/ScreenShot/
        let chessAppFolder   = docsURL.appendingPathComponent("ChessApp", isDirectory: true)
        let resolutionFolder = chessAppFolder.appendingPathComponent(finalResolution, isDirectory: true)
        let screenshotRoot   = resolutionFolder.appendingPathComponent("ScreenShot", isDirectory: true)
        
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: screenshotRoot,
                                   withIntermediateDirectories: true,
                                   attributes: nil)
        } catch {
            print("❌ Failed to create screenshot folder: \(error)")
            return .failure(.saveFailed)
        }
        
        // 4️⃣ 把 CGImage 转成 PNG Data
        let rep = NSBitmapImageRep(cgImage: image)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            print("❌ Failed to encode PNG data")
            return .failure(.encodeFailed)
        }
        
        let fileName = "\(current).png"
        let fileURL = screenshotRoot.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: fileURL, options: .atomic)
            print("💾 Saved PNG to: \(fileURL.path)")
        } catch {
            print("❌ Failed to save PNG: \(error)")
            return .failure(.saveFailed)
        }
        
        // 5️⃣ 从整屏截图中裁剪出棋盘图，保存到：
        //    ~/Documents/ChessApp/<resolution>/Board/<current>.png
        takeBoard(solution: finalResolution, current: current)
        
        // 6️⃣ 用模板 + 切块 + 分类 + FENEncoder，得到本局的 FEN
        let fenResult = generateFENFromBoard(solution: finalResolution, current: current, templates: templates)
        switch fenResult {
        case .success(let fen):
            print("✅ Final FEN = \(fen)")
            // 这里你之后可以：
            // - 把 FEN 存到某个状态
            // - 直接发给 Stockfish 计算下一步
        case .failure(let error):
            print("❌ Failed to generate FEN from board: \(error)")
            // 截图本身是成功的，所以仍然返回 .success(pngData)
        }
        
        // 7️⃣ 成功 → 返回 PNG 的 Data（FEN 通过日志输出）
        return .success(pngData)
        
    } catch {
        print("❌ captureFullScreenCGImage threw error: \(error)")
        return .failure(.captureFailed)
    }
}

/// 读取当前主屏幕分辨率（像素），存到 resolution，例如 "3840_2160"
func getScreenResolution() -> String? {
    guard let screen = NSScreen.main else {
        print("❌ 无法获取主屏幕信息")
        return nil
    }

    // frame 是点（points），需要乘以 backingScaleFactor 得到实际像素
    let frame = screen.frame
    let scale = screen.backingScaleFactor

    let widthPixels = Int(frame.width * scale)
    let heightPixels = Int(frame.height * scale)

    let value = "\(widthPixels)_\(heightPixels)"

    print("🖥 当前屏幕分辨率: \(value)")
    return value
}
