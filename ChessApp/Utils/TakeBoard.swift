//
//  TakeBoard.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation
import AppKit
import CoreGraphics

enum Constants {
    static let chessApp = "ChessApp"
    static let screenShot = "ScreenShot"
    static let board = "Board"
    static let square = "Square"
}

/// 从指定分辨率目录下，取 `ScreenShot/current.png`，裁剪棋盘区域，保存到 `Board` 文件夹
func takeBoard(solution: String, current: Int) {
    // 1. Choose crop parameters based on resolution
    let startX: CGFloat
    let startYFromTop: CGFloat
    let side: CGFloat
    
    switch solution {
    case "3840_2160":
        // 这些坐标是以屏幕左上角为原点测量的
        startX = 1156
        startYFromTop = 160
        side = 132
    case "1920_1080":
        startX = 642
        startYFromTop = 80
        side = 83
    default:
        print("⚠️ Unsupported solution: \(solution)")
        return
    }
    
    let fm = FileManager.default
    
    // 2. Locate Documents/ChessApp/(solution)
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    let chessAppFolder = docsURL.appendingPathComponent(Constants.chessApp, isDirectory: true)
    let resolutionFolder = chessAppFolder.appendingPathComponent(solution, isDirectory: true)
    let screenshotFolder = resolutionFolder.appendingPathComponent(Constants.screenShot, isDirectory: true)
    let boardFolder = resolutionFolder.appendingPathComponent(Constants.board, isDirectory: true)
    
    // 3. Ensure folders exist
    do {
        try fm.createDirectory(at: screenshotFolder,
                               withIntermediateDirectories: true,
                               attributes: nil)
    } catch {
        print("❌ Failed to create screenshot folder: \(error)")
        return
    }
    
    do {
        try fm.createDirectory(at: boardFolder,
                               withIntermediateDirectories: true,
                               attributes: nil)
    } catch {
        print("❌ Failed to create board folder: \(error)")
        return
    }
    
    // 4. 只处理一个文件：<current>.png
    let fileName = "\(current).png"
    let pngURL = screenshotFolder.appendingPathComponent(fileName)
    
    guard fm.fileExists(atPath: pngURL.path) else {
        print("⚠️ Screenshot file not found: \(pngURL.path)")
        return
    }
    
    // 5. 裁剪棋盘并保存到 Board
    autoreleasepool {
        guard let nsImage = NSImage(contentsOf: pngURL) else {
            print("❌ Cannot load image: \(pngURL.lastPathComponent)")
            return
        }
        
        guard let cgImage = nsImage.cgImage(forProposedRect: nil,
                                            context: nil,
                                            hints: nil) else {
            print("❌ Cannot get CGImage from: \(pngURL.lastPathComponent)")
            return
        }
        
        // ⚠️ CoreGraphics 以左下角为原点，需要从顶部坐标转换：
        // 原始注释：startYFromTop 是从“屏幕顶部”往下量的
        let imageHeight = CGFloat(cgImage.height)
        print(imageHeight)
        let cropOriginY = startYFromTop
        
        let cropRect = CGRect(
            x: startX,
            y: cropOriginY,
            width: side,
            height: side
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            print("❌ Failed to crop board from: \(pngURL.lastPathComponent)")
            return
        }
        
        let rep = NSBitmapImageRep(cgImage: croppedCGImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            print("❌ Failed to create PNG data for: \(pngURL.lastPathComponent)")
            return
        }
        
        let baseName = pngURL.deletingPathExtension().lastPathComponent
        let outputURL = boardFolder.appendingPathComponent("\(baseName).png")
        
        do {
            try pngData.write(to: outputURL, options: .atomic)
            print("✅ Saved board: \(outputURL.path)")
        } catch {
            print("❌ Failed to write board file for \(baseName): \(error)")
        }
    }
}
