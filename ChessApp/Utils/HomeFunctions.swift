//
//  HomeFunctions.swift
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

func homeBatchCropSquaresFromFullScreenshot(
    startX: CGFloat = 1156,
    startY: CGFloat = 160,
    side: CGFloat = 1328,
    step: CGFloat = 1,
    maxCount: Int = 1
) {
    let fm = FileManager.default
    
    // 1️⃣ Documents path
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // 2️⃣ Source folder: ~/Documents/Home/Full/
    let homeFolder = docsURL.appendingPathComponent("Home", isDirectory: true)
    let fullFolder = homeFolder.appendingPathComponent("Full", isDirectory: true)
    
    guard fm.fileExists(atPath: fullFolder.path) else {
        print("❌ Source folder not found: \(fullFolder.path)")
        return
    }
    
    // 2.1 获取所有 png 文件
    let allFiles: [URL]
    do {
        allFiles = try fm.contentsOfDirectory(
            at: fullFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    } catch {
        print("❌ Failed to list Full folder: \(error)")
        return
    }
    
    let pngFiles = allFiles.filter { $0.pathExtension.lowercased() == "png" }
    guard !pngFiles.isEmpty else {
        print("⚠️ No PNG files found in \(fullFolder.path)")
        return
    }
    
    print("📂 Found \(pngFiles.count) PNG file(s) in Full folder")
    
    // 3️⃣ Target root folder: ~/Documents/Home/Board/
    let boardFolder = homeFolder.appendingPathComponent("Board", isDirectory: true)
    do {
        if !fm.fileExists(atPath: boardFolder.path) {
            try fm.createDirectory(at: boardFolder, withIntermediateDirectories: true)
            print("📁 Created Board folder: \(boardFolder.path)")
        }
    } catch {
        print("❌ Failed to create Board folder: \(error)")
        return
    }
    
    // 4️⃣ 遍历每一个 PNG 文件
    for fullURL in pngFiles {
        let fullFileName = fullURL.lastPathComponent
        let baseName = (fullFileName as NSString).deletingPathExtension
        
        print("\n==============================")
        print("🎯 Processing: \(fullFileName)")
        
        // 4.1 读取图片
        guard let nsImage = NSImage(contentsOf: fullURL) else {
            print("❌ Cannot load image at \(fullURL.path)")
            continue
        }
        guard let fullCG = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Cannot get CGImage from \(fullFileName)")
            continue
        }
        
        let imgW = CGFloat(fullCG.width)
        let imgH = CGFloat(fullCG.height)
        print("✅ Loaded full image: \(Int(imgW))x\(Int(imgH))")
        
        // 4.2 针对该文件的目标目录: ~/Documents/Home/Board/baseName/
        let targetFolder = boardFolder.appendingPathComponent(baseName, isDirectory: true)
        
        // 4.3 创建 & 清空目标目录
        do {
            if !fm.fileExists(atPath: targetFolder.path) {
                try fm.createDirectory(at: targetFolder, withIntermediateDirectories: true)
                print("📁 Created subfolder: \(targetFolder.path)")
            } else {
                let files = try fm.contentsOfDirectory(
                    at: targetFolder,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                if !files.isEmpty {
                    print("🧹 Clearing \(files.count) existing file(s) in \(targetFolder.lastPathComponent)")
                }
                for url in files {
                    do {
                        try fm.removeItem(at: url)
                        print("🗑️ Removed: \(url.lastPathComponent)")
                    } catch {
                        print("⚠️ Failed to remove \(url.lastPathComponent): \(error)")
                    }
                }
            }
        } catch {
            print("❌ Failed to prepare target folder for \(baseName): \(error)")
            continue
        }
        
        // 4.4 对该 PNG 做裁剪
        var x = startX
        var y = startY
        var index = 0
        
        while (x + side <= imgW && y + side <= imgH) && index < maxCount {
            let cropRect = CGRect(x: x, y: y, width: side, height: side).integral
            print("🔪 [\(baseName)] Crop[\(index)] \(cropRect)")
            
            guard let cropped = fullCG.cropping(to: cropRect) else {
                print("⚠️ Crop failed at \(x), \(y)")
                x += step
                y += step
                index += 1
                continue
            }
            
            let rep = NSBitmapImageRep(cgImage: cropped)
            guard let data = rep.representation(using: .png, properties: [:]) else {
                print("⚠️ PNG encode failed at \(x), \(y)")
                x += step
                y += step
                index += 1
                continue
            }
            
            // 文件名：X_Y.png
            let fileName = "\(Int(x))_\(Int(y)).png"
            let fileURL = targetFolder.appendingPathComponent(fileName)
            
            do {
                try data.write(to: fileURL, options: .atomic)
                print("💾 Saved: \(fileName)")
            } catch {
                print("⚠️ Save failed: \(error)")
            }
            
            x += step
            y += step
            index += 1
        }
        
        print("✅ Finished \(baseName). Total crops = \(index)")
    }
    
    print("\n🎉 All PNG files processed.")
}


func homeSliceAllBoardsInto64Squares() {
    let fm = FileManager.default
    
    // 1️⃣ Documents path
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // 2️⃣ 根路径：~/Documents/Home/Board
    let homeFolder  = docsURL.appendingPathComponent("Home", isDirectory: true)
    let boardRoot   = homeFolder.appendingPathComponent("Board", isDirectory: true)
    let squareRoot  = homeFolder.appendingPathComponent("Square", isDirectory: true)
    
    // 确保 Board 存在
    guard fm.fileExists(atPath: boardRoot.path) else {
        print("❌ Board folder not found: \(boardRoot.path)")
        return
    }
    
    // 确保 Square 根目录存在
    do {
        if !fm.fileExists(atPath: squareRoot.path) {
            try fm.createDirectory(at: squareRoot, withIntermediateDirectories: true)
            print("📁 Created Square root: \(squareRoot.path)")
        }
    } catch {
        print("❌ Failed to create Square root: \(error)")
        return
    }
    
    // 3️⃣ 枚举 Board 下所有子目录
    let boardSubfolders: [URL]
    do {
        let contents = try fm.contentsOfDirectory(
            at: boardRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        boardSubfolders = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
    } catch {
        print("❌ Failed to list Board folder: \(error)")
        return
    }
    
    if boardSubfolders.isEmpty {
        print("⚠️ No subfolders found under \(boardRoot.path)")
        return
    }
    
    let columns = ["a","b","c","d","e","f","g","h"]
    
    for subfolder in boardSubfolders {
        let subfolderName = subfolder.lastPathComponent
        print("\n==============================")
        print("📂 Processing subfolder: \(subfolderName)")
        
        // 4️⃣ 找这个子目录下所有 PNG 文件
        let pngFiles: [URL]
        do {
            let files = try fm.contentsOfDirectory(
                at: subfolder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            pngFiles = files.filter { $0.pathExtension.lowercased() == "png" }
        } catch {
            print("⚠️ Failed to list files in \(subfolder.path): \(error)")
            continue
        }
        
        if pngFiles.isEmpty {
            print("⚠️ No PNG files in \(subfolder.path)")
            continue
        }
        
        // 5️⃣ 输出目录：~/Documents/Home/Square/<subfolderName>/
        let squareSubfolder = squareRoot.appendingPathComponent(subfolderName, isDirectory: true)
        do {
            if !fm.fileExists(atPath: squareSubfolder.path) {
                try fm.createDirectory(at: squareSubfolder, withIntermediateDirectories: true)
                print("📁 Created Square subfolder: \(squareSubfolder.path)")
            }
        } catch {
            print("❌ Failed to create Square subfolder for \(subfolderName): \(error)")
            continue
        }
        
        // 6️⃣ 对该子目录里的每一张棋盘图做 8×8 切图
        for boardURL in pngFiles {
            let boardName = boardURL.lastPathComponent
            let baseName  = (boardName as NSString).deletingPathExtension
            print("🎯 Board image: \(boardName)")
            
            guard let nsImage = NSImage(contentsOf: boardURL) else {
                print("❌ Cannot load image: \(boardURL.path)")
                continue
            }
            guard let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                print("❌ Cannot get CGImage from \(boardName)")
                continue
            }
            
            let width  = cg.width
            let height = cg.height
            let side   = min(width, height, 1328)   // 优先不超过 1328 的正方形
            let cell   = side / 8                   // 单格尺寸（Int）
            
            print("📐 board \(width)x\(height), use side=\(side), cell=\(cell)")
            
            if side <= 0 || cell <= 0 {
                print("⚠️ Invalid board size for \(boardName), skip.")
                continue
            }
            
            // 起点：左下角 (0,0)，裁剪 side×side 范围
            // 一共 8×8 格
            for row in 0..<8 {      // rank: 1..8
                for col in 0..<8 {  // file: a..h
                    let x = col * cell
                    let y = row * cell
                    let rect = CGRect(x: x, y: y, width: cell, height: cell)
                    
                    guard let cropped = cg.cropping(to: rect) else {
                        print("⚠️ Cropping failed at row=\(row), col=\(col) for \(boardName)")
                        continue
                    }
                    
                    let rep = NSBitmapImageRep(cgImage: cropped)
                    guard let data = rep.representation(using: .png, properties: [:]) else {
                        print("⚠️ PNG encode failed at row=\(row), col=\(col) for \(boardName)")
                        continue
                    }
                    
                    // 命名示例：bigBlack_a1.png, bigBlack_b1.png, ... bigBlack_h8.png
                    let fileName = "\(baseName)_\(columns[col])\(row+1).png"
                    let fileURL  = squareSubfolder.appendingPathComponent(fileName)
                    
                    do {
                        try data.write(to: fileURL, options: .atomic)
                        print("💾 Saved \(fileName)")
                    } catch {
                        print("❌ Failed writing \(fileName): \(error)")
                    }
                }
            }
            
            print("✅ Completed 64 squares for \(boardName)")
        }
    }
    
    print("\n🎉 All boards sliced into 64 squares.")
}

func homeProcessRightBottom() {
    let fm = FileManager.default
    
    // 1️⃣ ~/Documents
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // ⭐ NEW SOURCE: ~/Documents/Home/prepareSquare/prepareSquare
    let homeFolder = docsURL.appendingPathComponent("Home", isDirectory: true)
    var prepareSquareFolder = homeFolder
        .appendingPathComponent("prepareSquare", isDirectory: true)
    
    guard fm.fileExists(atPath: prepareSquareFolder.path) else {
        print("❌ Source folder prepareSquare does not exist: \(prepareSquareFolder.path)")
        return
    }
    prepareSquareFolder = prepareSquareFolder
        .appendingPathComponent("rightBottom", isDirectory: true)
    guard fm.fileExists(atPath: prepareSquareFolder.path) else {
        print("❌ Source folder rightBottom does not exist: \(prepareSquareFolder.path)")
        return
    }
    
    // 2️⃣ 列出 Source 目录下所有 PNG
    let urls: [URL]
    do {
        urls = try fm.contentsOfDirectory(
            at: prepareSquareFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    } catch {
        print("❌ Failed to list source folder: \(error)")
        return
    }
    
    let pngFiles = urls.filter { $0.pathExtension.lowercased() == "png" }
    
    guard !pngFiles.isEmpty else {
        print("⚠️ No PNG files in \(prepareSquareFolder.path)")
        return
    }
    
    print("🔍 Found \(pngFiles.count) PNG files in prepareSquare folder")
    
    
    // ⭐ NEW TARGET: ~/Documents/Home/Update Square
    let updateSquareFolder = homeFolder.appendingPathComponent("UpdateSquare", isDirectory: true)
    
    // 3️⃣ 如果不存在 → 创建 Update Square
    if !fm.fileExists(atPath: updateSquareFolder.path) {
        do {
            try fm.createDirectory(at: updateSquareFolder, withIntermediateDirectories: true)
            print("📁 Created Update Square folder: \(updateSquareFolder.path)")
        } catch {
            print("❌ Failed to create Update Square folder: \(error)")
            return
        }
    }
    
    // 4️⃣ 逐个处理 PNG
    for fileURL in pngFiles {
        autoreleasepool {
            processSingleRBPNG(at: fileURL, outputFolder: updateSquareFolder, targetwidth: 34, targetHeight: 48)
        }
    }
    
    print("✅ Finished processing all PNGs into Update Square")
}

func HomeProcessLeftTop() {
    let fm = FileManager.default
    
    // 1️⃣ ~/Documents
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // ~/Documents/Squares
    let homeFolder = docsURL.appendingPathComponent("Home", isDirectory: true)
    guard fm.fileExists(atPath: homeFolder.path) else {
        print("❌ Squares folder Home does not exist: \(homeFolder.path)")
        return
    }
    var prepareSquareURL = homeFolder.appendingPathComponent("prepareSquare", isDirectory: true)
    guard fm.fileExists(atPath: prepareSquareURL.path) else {
        print("❌ Squares folder prepareSquare does not exist: \(prepareSquareURL.path)")
        return
    }
    prepareSquareURL = prepareSquareURL.appendingPathComponent("leftTop", isDirectory: true)
    guard fm.fileExists(atPath: prepareSquareURL.path) else {
        print("❌ Squares folder leftTop does not exist: \(prepareSquareURL.path)")
        return
    }
    
    let updateSquareFolder = homeFolder.appendingPathComponent("UpdateSquare", isDirectory: true)
    
    // 3️⃣ 如果不存在 → 创建 Update Square
    if !fm.fileExists(atPath: updateSquareFolder.path) {
        do {
            try fm.createDirectory(at: updateSquareFolder, withIntermediateDirectories: true)
            print("📁 Created Update Square folder: \(updateSquareFolder.path)")
        } catch {
            print("❌ Failed to create Update Square folder: \(error)")
            return
        }
    }
    
    // 2️⃣ 找出所有 *LT.png
    let urls: [URL]
    do {
        urls = try fm.contentsOfDirectory(
            at: prepareSquareURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    } catch {
        print("❌ Failed to list Squares folder: \(error)")
        return
    }
    
    
    guard !urls.isEmpty else {
        print("⚠️ No png files found in \(prepareSquareURL.path)")
        return
    }
    
    print("🔍 Found \(urls.count)  png files")
    
    for fileURL in urls {
        autoreleasepool {
            processSingleLeftTopPNG(at: fileURL, outputFolder: updateSquareFolder)
        }
    }
    
    print("✅ Home ProcessLeftTop finished")
}


@MainActor
func homeCaptureFullAndBoardAndSaveToDocuments() async -> Result<Data, CaptureError> {
    do {
        // 1️⃣ 用 ScreenCaptureKit 截整屏（主显示器）
        guard let fullImage = try await captureFullScreenCGImage() else {
            return .failure(.captureFailed)
        }
        
        let timestamp = currentTimestampString()
        
        // 2️⃣ 整屏转 PNG，保存到 ~/Documents/Home
        guard let fullData = pngData(from: fullImage),
            let fileUrlString = savePNGToDocuments(data: fullData,
                                                   fileName: "Full_\(timestamp).png") else {
            return .failure(.saveFailed)
        }
            
        if let fileUrl = homeCropSquaresFromFullScreenshot(fileUrlString: fileUrlString) {
            ///Users/stone.yan/Documents/Home/CutBoard/Full_20251115_024355_board.png
            
            
            return .failure(.captureFailed)
        } else {
            return .failure(.captureFailed)
        }
        
    } catch {
        print("❌ captureFullAndBoardAndSaveToDocuments error: \(error)")
        return .failure(.captureFailed)
    }
}

func homeCropSquaresFromFullScreenshot(
    startX: CGFloat = 1156,
    startY: CGFloat = 160,
    side: CGFloat = 1328,
    fileUrlString: String
) -> String? {
    let fm = FileManager.default
    
    // 1️⃣ ~/Documents
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return nil
    }
    
    // 2️⃣ 把 fileUrlString 解析成 URL
    //    支持两种形式：
    //    1. 纯路径: "/Users/.../xxx.png"
    //    2. file URL: "file:///Users/.../xxx.png"
    let fullURL: URL
    if let url = URL(string: fileUrlString), url.isFileURL {
        // 传进来是 "file:///..." 这种
        fullURL = url
    } else {
        // 传进来是普通路径
        fullURL = URL(fileURLWithPath: fileUrlString)
    }
    
    print("📄 Using source URL: \(fullURL)")
    
    guard fm.fileExists(atPath: fullURL.path) else {
        print("❌ Source file not found at path: \(fullURL.path)")
        return nil
    }
    
    let fullFileName = fullURL.lastPathComponent
    let baseName = (fullFileName as NSString).deletingPathExtension
    
    print("\n==============================")
    print("🎯 Processing single file: \(fullFileName)")
    
    // 3️⃣ 读取图片
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
    
    // 5️⃣ 目标目录：~/Documents/Home/CutBoard/
    let homeFolder     = docsURL.appendingPathComponent("Home", isDirectory: true)
    let cutBoardFolder = homeFolder.appendingPathComponent("CutBoard", isDirectory: true)
    
    do {
        if !fm.fileExists(atPath: cutBoardFolder.path) {
            try fm.createDirectory(at: cutBoardFolder, withIntermediateDirectories: true)
            print("📁 Created CutBoard folder: \(cutBoardFolder.path)")
        }
    } catch {
        print("❌ Failed to create CutBoard folder: \(error)")
        return nil
    }
    
    // 6️⃣ 输出文件名：<原名>_board.png
    let outputFileName = "\(baseName)_board.png"
    let outputURL = cutBoardFolder.appendingPathComponent(outputFileName)
    
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
