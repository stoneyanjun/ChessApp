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
func captureScreenShot(current: Int) async -> Result<Data, CaptureError> {
    do {
        // 1️⃣ 调用你之前的 captureFullScreenCGImage()
        let (imageOpt, resolution) = try await finialCaptureFullScreen()
        
        guard let image = imageOpt else {
            print("❌ captureFullScreenCGImage returned nil image")
            return .failure(.noImage)
        }
        
        let resolutionFolderName = resolution.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalResolution = resolutionFolderName.isEmpty ? "UnknownResolution" : resolutionFolderName
        
        // 3️⃣ 定位 ~/Documents
        guard let docsURL = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask).first else {
            print("❌ Cannot locate Documents folder")
            return .failure(.documentsNotFound)
        }
        
        // 4️⃣ 目标目录：~/Documents/ChessApp/ScreenShot/<resolution>/
        let chessAppFolder = docsURL.appendingPathComponent("ChessApp", isDirectory: true)
        let resolutionFolder = chessAppFolder.appendingPathComponent(finalResolution, isDirectory: true)
        let screenshotRoot = resolutionFolder.appendingPathComponent("ScreenShot", isDirectory: true)
        
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: screenshotRoot,
                                   withIntermediateDirectories: true,
                                   attributes: nil)
        } catch {
            print("❌ Failed to create screenshot folder: \(error)")
            return .failure(.saveFailed)
        }
        
        // 5️⃣ 把 CGImage 转成 PNG Data
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
        
        takeBoard(solution: resolution, current: current)
        
        // 7️⃣ 成功 → 返回 PNG 的 Data
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
