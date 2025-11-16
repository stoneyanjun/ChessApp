//
//  Capture1080.swift
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


enum CaptureError: Error, Equatable {
    case noImage
    case documentsNotFound
    case encodeFailed
    case noWindow
    case captureFailed
    case saveFailed
}

@MainActor
func finialCaptureFullScreen() async throws -> (image: CGImage?, resolution: String) {
    let content = try await SCShareableContent.current
    
    // 取宽度最大的显示器
    guard let display = content.displays.max(by: { $0.width < $1.width }) else {
        print("❌ No display found")
        return (nil, "")
    }
    
    let filter = SCContentFilter(display: display, excludingWindows: [])
    
    let config = SCStreamConfiguration()
    config.capturesAudio = false
    config.showsCursor = false
    
    // 保持原始分辨率（point → pixel）
    let pixelScale = CGFloat(filter.pointPixelScale)
    config.width  = Int(filter.contentRect.width  * pixelScale)
    config.height = Int(filter.contentRect.height * pixelScale)
    
    let resolutionString = "\(config.width)_\(config.height)"    // ⭐ “19201080” 格式
    
    let image = try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: config
    )
    
    print("✅ Full screen captured: \(image.width)x\(image.height)")
    print("🔢 Resolution string: \(resolutionString)")
    
    return (image, resolutionString)
}


func tryFinialCropBoards(
    fileUrlString: String,
    startX: CGFloat = 578,
    startY: CGFloat = 80,
    side: CGFloat = 664,
    step: CGFloat = 1,
    maxAttempts: Int = 1
) {
    var currentX = startX
    var currentY = startY
    var attemptCount = 0
    while attemptCount < maxAttempts {
        finialCropBoard(
            fileUrlString: fileUrlString,
            startX: currentX,
            startY: currentY,
            side: side
        )
        currentX += step
        currentY += step
        attemptCount += 1
    }
}

func finialCropBoard(
    fileUrlString: String,
    startX: CGFloat = 578,
    startY: CGFloat = 80,
    side: CGFloat = 664,
) -> String? {
    let fm = FileManager.default
    
    let fullURL: URL
    if let url = URL(string: fileUrlString), url.isFileURL {
        fullURL = url
    } else {
        fullURL = URL(fileURLWithPath: fileUrlString)
    }
    guard fm.fileExists(atPath: fullURL.path) else {
        print("❌ Source file not found at path: \(fullURL.path)")
        return nil
    }
    
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return nil
    }
    
    let fullFileName = fullURL.lastPathComponent
    let baseName = (fullFileName as NSString).deletingPathExtension
    print("🎯 finialCropSquare Processing screen shot: \(fullFileName)")
    guard let nsImage = NSImage(contentsOf: fullURL) else {
        print("❌ Cannot load image at \(fullURL.path)")
        return nil
    }
    guard let fullCG = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("❌ Cannot get CGImage from \(fullFileName)")
        return nil
    }
    
    let imgW = CGFloat(fullCG.width)
    let imgH = CGFloat(fullCG.height)
    print("✅ Loaded full image: \(Int(imgW))x\(Int(imgH))")
    
    // 4️⃣ 校验裁剪区域是否在图像范围内
    guard startX >= 0, startY >= 0,
          startX + side <= imgW,
          startY + side <= imgH else {
        print("⚠️ Crop rect out of bounds: startX=\(startX), startY=\(startY), side=\(side)")
        return nil
    }
    
    let cropRect = CGRect(x: startX, y: startY, width: side, height: side).integral
    print("🔪 Crop rect = \(cropRect)")
    
    guard let cropped = fullCG.cropping(to: cropRect) else {
        print("⚠️ Cropping failed")
        return nil
    }
    
    let rep = NSBitmapImageRep(cgImage: cropped)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("⚠️ PNG encode failed")
        return nil
    }
    
    // 5️⃣ 目标目录：~/Documents/ChessApp/CutBoard/
    let chessAppFolder = docsURL.appendingPathComponent("ChessApp", isDirectory: true)
    let boardFolder = chessAppFolder.appendingPathComponent("Board", isDirectory: true)
    let resolution = "\(Int(imgW))\(Int(imgH))"
    let resolutionFolder = boardFolder.appendingPathComponent(resolution, isDirectory: true)
    
    do {
        if !fm.fileExists(atPath: chessAppFolder.path) {
            try fm.createDirectory(at: chessAppFolder, withIntermediateDirectories: true)
            print("📁 Created chessAppFolder folder: \(chessAppFolder.path)")
        }
        if !fm.fileExists(atPath: boardFolder.path) {
            try fm.createDirectory(at: boardFolder, withIntermediateDirectories: true)
            print("📁 Created boardFolder folder: \(boardFolder.path)")
        }
        if !fm.fileExists(atPath: resolutionFolder.path) {
            try fm.createDirectory(at: resolutionFolder, withIntermediateDirectories: true)
            print("📁 Created resolution folder: \(resolutionFolder.path)")
        }
    } catch {
        print("❌ Failed to create resolution folder: \(error)")
        return nil
    }
    
    // 6️⃣ 输出文件名：<原名>_board.png
    let outputFileName = "board_\(baseName)_\(Int(startX))_\(Int(startY)).png"
    let outputURL = resolutionFolder.appendingPathComponent(outputFileName)
    
    do {
        try data.write(to: outputURL, options: .atomic)
        print("💾 Saved board image → \(outputURL.path)")
    } catch {
        print("⚠️ Save failed: \(error)")
        return nil
    }
    
    print("✅ Finished processing single board image.")
    return outputURL.path
}

func finalCut64Squares(sourceBoardFolder: String,
                       targetSquareFolder: String) {
    let fm = FileManager.default
    
    // 1️⃣ Locate ~/Documents
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // 2️⃣ Build source / target URLs
    //    - If parameter starts with "/", treat as absolute path.
    //    - Otherwise, treat as relative to ~/Documents.
    let sourceURL: URL
    if sourceBoardFolder.hasPrefix("/") {
        sourceURL = URL(fileURLWithPath: sourceBoardFolder, isDirectory: true)
    } else {
        sourceURL = docsURL.appendingPathComponent(sourceBoardFolder, isDirectory: true)
    }
    
    let targetURL: URL
    if targetSquareFolder.hasPrefix("/") {
        targetURL = URL(fileURLWithPath: targetSquareFolder, isDirectory: true)
    } else {
        targetURL = docsURL.appendingPathComponent(targetSquareFolder, isDirectory: true)
    }
    
    // Example call for your case:
    // sourceBoardFolder: "ChessApp/Board/readyBoard"
    // targetSquareFolder: "ChessApp/Square"
    
    guard fm.fileExists(atPath: sourceURL.path) else {
        print("❌ Source folder not found: \(sourceURL.path)")
        return
    }
    
    // 3️⃣ Ensure target root exists
    do {
        if !fm.fileExists(atPath: targetURL.path) {
            try fm.createDirectory(at: targetURL,
                                   withIntermediateDirectories: true)
            print("📁 Created target folder: \(targetURL.path)")
        }
    } catch {
        print("❌ Failed to create target folder: \(error)")
        return
    }
    
    // 4️⃣ List all PNG files in source folder
    let allFiles: [URL]
    do {
        allFiles = try fm.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    } catch {
        print("❌ Failed to list source folder: \(error)")
        return
    }
    
    let pngFiles = allFiles.filter { $0.pathExtension.lowercased() == "png" }
    guard !pngFiles.isEmpty else {
        print("⚠️ No PNG files found in \(sourceURL.path)")
        return
    }
    
    print("📂 Found \(pngFiles.count) PNG file(s) in source folder")
    
    let columns = ["a", "b", "c", "d", "e", "f", "g", "h"]
    
    // 5️⃣ Process each PNG board
    for boardURL in pngFiles {
        let baseFileName = (boardURL.deletingPathExtension().lastPathComponent)
        print("\n==============================")
        print("🎯 Processing board: \(baseFileName)")
        
        guard let nsImage = NSImage(contentsOf: boardURL) else {
            print("❌ Cannot load image: \(boardURL.path)")
            continue
        }
        guard let cg = nsImage.cgImage(forProposedRect: nil,
                                       context: nil,
                                       hints: nil) else {
            print("❌ Cannot get CGImage for \(baseFileName)")
            continue
        }
        
        let width  = cg.width
        let height = cg.height
        
        if width != height {
            print("⚠️ Board is not square: \(width)x\(height), using min side")
        }
        
        let side = min(width, height)    // e.g. 1328
        let cell = side / 8              // e.g. 166
        
        print("📐 board \(width)x\(height), cut using side=\(side), cell=\(cell)")
        
        // 逐格切图：row 0..7, col 0..7
        for row in 0..<8 {
            for col in 0..<8 {
                let x = col * cell
                let y = row * cell
                let rect = CGRect(x: x, y: y, width: cell, height: cell)
                
                guard let cropped = cg.cropping(to: rect) else {
                    print("⚠️ Cropping failed at row=\(row), col=\(col)")
                    continue
                }
                
                let rep = NSBitmapImageRep(cgImage: cropped)
                guard let data = rep.representation(using: .png, properties: [:]) else {
                    print("⚠️ PNG encode failed at row=\(row), col=\(col)")
                    continue
                }
                
                // 📛 File name: baseFileName + 1a / 1b / ... / 8h
                // Example: "readyBoard1a.png"
                let rank = row + 1
                let fileChar = columns[col]
                let squareName = "\(baseFileName)\(rank)\(fileChar).png"
                
                let outURL = targetURL.appendingPathComponent(squareName)
                
                do {
                    try data.write(to: outURL, options: .atomic)
                    print("💾 Saved \(squareName)")
                } catch {
                    print("❌ Failed to save \(squareName): \(error)")
                }
            }
        }
        
        print("✅ Completed 64 squares for \(baseFileName)")
    }
    
    print("\n🎉 All boards cut into 64 squares.")
}
