import Foundation
import AppKit
import CoreGraphics

enum Constants {
    static let chessApp = "ChessApp"
    static let screenShot = "ScreenShot"
    static let board = "Board"
    static let square = "Square"
}

/// 从指定分辨率目录下，取 `ScreenShot/current.png`，
/// 按“左下角为原点”的坐标裁剪出棋盘区域，保存到 `Board` 文件夹。
func takeBoard(solution: String, current: Int) {
    // 1. 按分辨率选择裁剪参数（全部按 CGImage 坐标：左下角为原点）
    let startX: CGFloat
    let startY: CGFloat
    let side: CGFloat
    
    switch solution {
    case "3840_2160":
        // ✅ 这组是你已验证能用的参数（从左下角量）
        // 如果你之前用的是 side = 1328，就改回 1328
        startX = 1156
        startY = 160
        side   = 1328   // 或者 132，看你实际验证过哪一个
    case "1920_1080":
        // ✅ 直接复用 oldbatchCropSquaresFromFullScreenshot 中已验证过的一组
        // oldbatch: startX=642, startY=80, side=664
        startX = 578
        startY = 80
        side   = 664
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
        
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        print("📏 Screenshot size = \(Int(imgW)) x \(Int(imgH))")
        print("📐 Crop board at (x=\(startX), y=\(startY)), side=\(side)")
        
        let cropRect = CGRect(
            x: startX,
            y: startY,
            width: side,
            height: side
        ).integral
        
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
