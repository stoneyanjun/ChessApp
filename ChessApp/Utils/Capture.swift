//
//  Capture.swift
//  ChessApp
//
//  Created by stone on 2025/11/14.
//

import Foundation
import ComposableArchitecture
import AppKit
import CoreGraphics
import ScreenCaptureKit
import Vision

///////////////////////////////////////////////////////////
// MARK: - 主流程：整屏 + 棋盘裁剪 + 保存到 ~/Documents/Chess
///////////////////////////////////////////////////////////

@MainActor
func captureFullAndBoardAndSaveToDocuments() async -> Result<Data, CaptureError> {
    do {
        // 1️⃣ 用 ScreenCaptureKit 截整屏（主显示器）
        guard let fullImage = try await captureFullScreenCGImage() else {
            return .failure(.captureFailed)
        }
        
        let timestamp = currentTimestampString()
        
        // 2️⃣ 整屏转 PNG，保存到 ~/Documents/Home
        if let fullData = pngData(from: fullImage) {
            savePNGToDocuments(data: fullData,
                               fileName: "Full_\(timestamp).png")
        }
        
        // 3️⃣ 用 Vision + 小方格 + 8×8 网格约束检测棋盘矩形
        guard let boardRect = detectChessBoardRectWithGrid(in: fullImage) else {
            print("❌ Failed to detect chess board rect (with grid)")
            return .failure(.captureFailed)
        }
        
        guard let boardCG = fullImage.cropping(to: boardRect),
              let boardData = pngData(from: boardCG) else {
            print("❌ Failed to crop board image")
            return .failure(.captureFailed)
        }
        
        // 4️⃣ 棋盘 PNG 保存到 ~/Documents/Chess
        savePNGToDocuments(data: boardData,
                           fileName: "Board_\(timestamp).png")
        
        print("✅ Board captured & saved. rect=\(boardRect)")
        return .success(boardData)
        
    } catch {
        print("❌ captureFullAndBoardAndSaveToDocuments error: \(error)")
        return .failure(.captureFailed)
    }
}

///////////////////////////////////////////////////////////
// MARK: - ScreenCaptureKit：整屏截图（主显示器）
///////////////////////////////////////////////////////////

@MainActor
func captureFullScreenCGImage() async throws -> CGImage? {
    let content = try await SCShareableContent.current
    
    // 取宽度最大的显示器作为“主屏”
    guard let display = content.displays.max(by: { $0.width < $1.width }) else {
        print("❌ No display found")
        return nil
    }
    
    let filter = SCContentFilter(display: display, excludingWindows: [])
    
    let config = SCStreamConfiguration()
    config.capturesAudio = false
    config.showsCursor = false
    
    // 保持原始分辨率（point → pixel）
    let pixelScale = CGFloat(filter.pointPixelScale)
    config.width  = Int(filter.contentRect.width  * pixelScale)
    config.height = Int(filter.contentRect.height * pixelScale)
    
    let image = try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: config
    )
    
    print("✅ Full screen captured: \(image.width)x\(image.height)")
    return image
}

///////////////////////////////////////////////////////////
// MARK: - PNG & 保存到 ~/Documents/Chess
///////////////////////////////////////////////////////////

func pngData(from cgImage: CGImage) -> Data? {
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:])
}

func currentTimestampString() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    return formatter.string(from: Date())
}

/// 保存 PNG 到 ~/Documents/Chess/fileName
func savePNGToDocuments(data: Data, fileName: String) -> String? {
    let fm = FileManager.default
    
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return nil
    }
    
    // ~/Documents/Home
    let homeFolder = docsURL.appendingPathComponent("Home", isDirectory: true)
    
    if !fm.fileExists(atPath: homeFolder.path) {
        do {
            try fm.createDirectory(at: homeFolder,
                                   withIntermediateDirectories: true)
            print("📁 Created folder: \(homeFolder.path)")
        } catch {
            print("❌ Failed to create Home folder: \(error)")
            return nil
        }
    }
    
    let chessScreenShotsFolder = homeFolder.appendingPathComponent("ChessScreenShots", isDirectory: true)
    
    if !fm.fileExists(atPath: chessScreenShotsFolder.path) {
        do {
            try fm.createDirectory(at: chessScreenShotsFolder,
                                   withIntermediateDirectories: true)
            print("📁 Created folder: \(chessScreenShotsFolder.path)")
        } catch {
            print("❌ Failed to create chessScreenShotsFolder folder: \(error)")
            return nil
        }
    }
    
    
    let fileURL = chessScreenShotsFolder.appendingPathComponent(fileName)
    
    do {
        try data.write(to: fileURL, options: .atomic)
        print("💾 Saved PNG to: \(fileURL.path)")
        return fileURL.absoluteString
    } catch {
        print("❌ Failed to save PNG: \(error)")
        return nil
    }
}

///////////////////////////////////////////////////////////
// MARK: - 方案 A：ROI + 大矩形（粗棋盘，用作兜底）
///////////////////////////////////////////////////////////

/// 原始的 ROI + 大矩形检测（作为兜底）
func detectChessBoardRect(in cgImage: CGImage) -> CGRect? {
    let fullW  = CGFloat(cgImage.width)
    let fullH  = CGFloat(cgImage.height)
    let fullCenter = CGPoint(x: fullW / 2, y: fullH / 2)
    
    // 只取中间区域作为 ROI：排除左侧栏和右侧面板
    var roiInFull = CGRect(
        x: fullW * 0.15,
        y: fullH * 0.05,
        width: fullW * 0.70,
        height: fullH * 0.90
    ).integral
    
    let roiCGImage: CGImage
    if let cropped = cgImage.cropping(to: roiInFull) {
        roiCGImage = cropped
    } else {
        roiInFull = CGRect(x: 0, y: 0, width: fullW, height: fullH)
        roiCGImage = cgImage
    }
    
    let roiW = CGFloat(roiCGImage.width)
    let roiH = CGFloat(roiCGImage.height)
    
    let request = VNDetectRectanglesRequest()
    request.minimumAspectRatio = 0.8
    request.maximumAspectRatio = 1.2
    request.minimumSize = 0.1
    request.maximumObservations = 30
    request.minimumConfidence = 0.3
    request.quadratureTolerance = 20.0
    
    let handler = VNImageRequestHandler(cgImage: roiCGImage, options: [:])
    
    do {
        try handler.perform([request])
    } catch {
        print("❌ VNDetectRectanglesRequest failed: \(error)")
    }
    
    if let observations = request.results, !observations.isEmpty {
        var bestRectInFull: CGRect?
        var bestScore: CGFloat = -1
        
        for obs in observations {
            let bb = obs.boundingBox   // [0,1] in ROI
            
            let rectInROI = CGRect(
                x: bb.origin.x * roiW,
                y: (1 - bb.origin.y - bb.height) * roiH,
                width: bb.width * roiW,
                height: bb.height * roiH
            )
            
            let rectInFull = CGRect(
                x: rectInROI.origin.x + roiInFull.origin.x,
                y: rectInROI.origin.y + roiInFull.origin.y,
                width: rectInROI.width,
                height: rectInROI.height
            )
            
            let side = min(rectInFull.width, rectInFull.height)
            guard side >= 400 else { continue }
            
            let nx = rectInFull.midX / fullW
            let ny = rectInFull.midY / fullH
            guard nx > 0.2, nx < 0.8, ny > 0.2, ny < 0.8 else { continue }
            
            let center = CGPoint(x: rectInFull.midX, y: rectInFull.midY)
            let dist = hypot(center.x - fullCenter.x, center.y - fullCenter.y)
            let score = side - dist * 0.2
            
            if score > bestScore {
                bestScore = score
                bestRectInFull = rectInFull
            }
        }
        
        if var found = bestRectInFull {
            let side = min(found.width, found.height)
            found = CGRect(
                x: found.midX - side / 2,
                y: found.midY - side / 2,
                width: side,
                height: side
            )
            print("🎯 Vision(ROI) detected board rect: \(found)")
            return found
        }
    } else {
        print("⚠️ Vision found no rectangles in ROI")
    }
    
    // Fallback：中心附近裁一块
    let minSideRequired: CGFloat = 400
    var side = min(fullW, fullH) * 0.7
    if side < minSideRequired {
        side = min(minSideRequired, min(fullW, fullH))
    }
    
    var originX = (fullW  - side) / 2
    var originY = (fullH - side) / 2
    
    originY -= fullH * 0.03
    
    originX = max(0, min(originX, fullW  - side))
    originY = max(0, min(originY, fullH - side))
    
    let fallbackRect = CGRect(x: originX, y: originY, width: side, height: side)
    print("🎯 Fallback board rect: \(fallbackRect)")
    return fallbackRect
}

///////////////////////////////////////////////////////////
// MARK: - 方案 B：检测很多小方格，反推出棋盘区域
///////////////////////////////////////////////////////////

func detectChessBoardRectBySquares(in cgImage: CGImage) -> CGRect? {
    let fullW  = CGFloat(cgImage.width)
    let fullH  = CGFloat(cgImage.height)
    
    // 与上面一致的 ROI
    var roiInFull = CGRect(
        x: fullW * 0.15,
        y: fullH * 0.05,
        width: fullW * 0.70,
        height: fullH * 0.90
    ).integral
    
    let roiCGImage: CGImage
    if let cropped = cgImage.cropping(to: roiInFull) {
        roiCGImage = cropped
    } else {
        roiInFull = CGRect(x: 0, y: 0, width: fullW, height: fullH)
        roiCGImage = cgImage
    }
    
    let roiW = CGFloat(roiCGImage.width)
    let roiH = CGFloat(roiCGImage.height)
    
    let request = VNDetectRectanglesRequest()
    request.minimumAspectRatio = 0.9
    request.maximumAspectRatio = 1.1
    request.minimumSize = 0.02
    request.maximumObservations = 256
    request.minimumConfidence = 0.25
    request.quadratureTolerance = 20.0
    
    let handler = VNImageRequestHandler(cgImage: roiCGImage, options: [:])
    
    do {
        try handler.perform([request])
    } catch {
        print("❌ VNDetectRectanglesRequest (squares) failed: \(error)")
        return nil
    }
    
    guard let observations = request.results, !observations.isEmpty else {
        print("⚠️ No small squares detected in ROI")
        return nil
    }
    
    var candidates: [CGRect] = []
    
    for obs in observations {
        let bb = obs.boundingBox
        
        let rectInROI = CGRect(
            x: bb.origin.x * roiW,
            y: (1 - bb.origin.y - bb.height) * roiH,
            width: bb.width * roiW,
            height: bb.height * roiH
        )
        
        let rectInFull = CGRect(
            x: rectInROI.origin.x + roiInFull.origin.x,
            y: rectInROI.origin.y + roiInFull.origin.y,
            width: rectInROI.width,
            height: rectInROI.height
        )
        
        let w = rectInFull.width
        let h = rectInFull.height
        let side = min(w, h)
        let aspect = side / max(w, h)
        
        let minCell = min(fullW, fullH) * 0.02
        let maxCell = min(fullW, fullH) * 0.20
        
        guard aspect > 0.9,
              side >= minCell,
              side <= maxCell else {
            continue
        }
        
        let nx = rectInFull.midX / fullW
        let ny = rectInFull.midY / fullH
        guard nx > 0.15, nx < 0.85, ny > 0.15, ny < 0.85 else {
            continue
        }
        
        candidates.append(rectInFull)
    }
    
    guard !candidates.isEmpty else {
        print("⚠️ Small-rect candidates all filtered out")
        return nil
    }
    
    var minX = CGFloat.greatestFiniteMagnitude
    var maxX = CGFloat.leastNonzeroMagnitude
    var minY = CGFloat.greatestFiniteMagnitude
    var maxY = CGFloat.leastNonzeroMagnitude
    
    for r in candidates {
        minX = min(minX, r.minX)
        maxX = max(maxX, r.maxX)
        minY = min(minY, r.minY)
        maxY = max(maxY, r.maxY)
    }
    
    let roughRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    print("🎯 detectChessBoardRectBySquares → \(roughRect) from \(candidates.count) squares")
    return roughRect
}

///////////////////////////////////////////////////////////
// MARK: - 8×8 网格对齐
///////////////////////////////////////////////////////////

private func snapRectTo8x8Grid(_ roughRect: CGRect, imageSize: CGImage) -> CGRect {
    let imageWidth  = CGFloat(imageSize.width)
    let imageHeight = CGFloat(imageSize.height)
    
    let roughSide = min(roughRect.width, roughRect.height)
    
    let rawCellSize = roughSide / 8.0
    var cellSize = floor(rawCellSize)
    if cellSize < 1 { cellSize = 1 }
    
    var side = cellSize * 8.0
    
    if side < 400 {
        side = max(400, min(imageWidth, imageHeight))
        side = floor(side / 8.0) * 8.0
    }
    
    var centerX = roughRect.midX
    var centerY = roughRect.midY
    
    centerX = max(side / 2, min(centerX, imageWidth  - side / 2))
    centerY = max(side / 2, min(centerY, imageHeight - side / 2))
    
    var originX = centerX - side / 2.0
    var originY = centerY - side / 2.0
    
    originX = max(0, min(originX, imageWidth  - side))
    originY = max(0, min(originY, imageHeight - side))
    
    let finalOriginX = floor(originX)
    let finalOriginY = floor(originY)
    
    let finalRect = CGRect(x: finalOriginX, y: finalOriginY, width: side, height: side)
    print("🎯 snapRectTo8x8Grid → \(finalRect)")
    return finalRect
}

///////////////////////////////////////////////////////////
// MARK: - 组合方案入口
///////////////////////////////////////////////////////////

/// 组合方案入口：
/// 1️⃣ 优先用“小方格云”反推棋盘（一般略小于真实棋盘）
///    - 在此基础上放大一圈（≈1.15），再 8×8 对齐 → 得到 ~640 的边长
/// 2️⃣ 如果小方格失败，再退回 ROI 大矩形方案
func detectChessBoardRectWithGrid(in cgImage: CGImage) -> CGRect? {
    let fullW  = CGFloat(cgImage.width)
    let fullH  = CGFloat(cgImage.height)
    let maxSide = min(fullW, fullH)
    
    // 1️⃣ Squares：优先
    if let squaresRect = detectChessBoardRectBySquares(in: cgImage) {
        let sideSquares = min(squaresRect.width, squaresRect.height)
        
        // 放大系数：经验值 1.15
        var enlargedSide = sideSquares * 1.15
        enlargedSide = max(400, min(enlargedSide, maxSide))
        
        var originX = squaresRect.midX - enlargedSide / 2.0
        var originY = squaresRect.midY - enlargedSide / 2.0
        
        originX = max(0, min(originX, fullW  - enlargedSide))
        originY = max(0, min(originY, fullH - enlargedSide))
        
        let enlargedRect = CGRect(x: originX, y: originY, width: enlargedSide, height: enlargedSide)
        print("🔧 Enlarged from squares → \(enlargedRect)")
        
        let snapped = snapRectTo8x8Grid(enlargedRect, imageSize: cgImage)
        print("🎯 Board rect from squares + grid: \(snapped)")
        return snapped
    }
    
    // 2️⃣ Squares 失败 → ROI 兜底
    if let rough = detectChessBoardRect(in: cgImage) {
        let snapped = snapRectTo8x8Grid(rough, imageSize: cgImage)
        print("🎯 Board rect from ROI + grid: \(snapped)")
        return snapped
    }
    
    print("❌ detectChessBoardRectWithGrid: all methods failed")
    return nil
}

func oldbatchCropSquaresFromFullScreenshot(
    fullFileName: String = "white.png",
    startX: CGFloat = 642,
    startY: CGFloat = 80,
    side: CGFloat = 664,
    step: CGFloat = 1
) {
    let fm = FileManager.default
    
    // 1️⃣ 找到 ~/Documents/Chess/Full_....png
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    let chessFolder = docsURL.appendingPathComponent("Chess", isDirectory: true)
    let fullURL = chessFolder.appendingPathComponent(fullFileName)
    
    guard let nsImage = NSImage(contentsOf: fullURL) else {
        print("❌ Cannot load image at \(fullURL.path)")
        return
    }
    
    guard let fullCG = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("❌ Cannot get CGImage from NSImage")
        return
    }
    
    let imgW = CGFloat(fullCG.width)
    let imgH = CGFloat(fullCG.height)
    print("✅ Loaded full image: \(Int(imgW))x\(Int(imgH)) from \(fullURL.path)")
    
    // 2️⃣ 创建时间字符串目录 ~/Documents/Chess/<hh-mm-ss>/
    let formatter = DateFormatter()
    formatter.dateFormat = "HH-mm-ss"
    let timeString = formatter.string(from: Date())
    
    let outputFolder = chessFolder.appendingPathComponent(timeString, isDirectory: true)
    
    if !fm.fileExists(atPath: outputFolder.path) {
        do {
            try fm.createDirectory(at: outputFolder, withIntermediateDirectories: true)
            print("📁 Created folder: \(outputFolder.path)")
        } catch {
            print("❌ Failed to create output folder: \(error)")
            return
        }
    }
    
    // 3️⃣ 从 (startX, startY) 开始迭代裁剪
    var x = startX
    var y = startY
    var index = 0
    
    while (x + side <= imgW && y + side <= imgH) && (index < 8) {
        let cropRect = CGRect(x: x, y: y, width: side, height: side).integral
        print("🔪 Crop[\(index)] rect = \(cropRect)")
        
        guard let cropped = fullCG.cropping(to: cropRect) else {
            print("⚠️ cropping failed at x=\(x), y=\(y)")
            x += step
            y += step
            index += 1
            continue
        }
        
        let rep = NSBitmapImageRep(cgImage: cropped)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            print("⚠️ PNG encode failed at x=\(x), y=\(y)")
            x += step
            y += step
            index += 1
            continue
        }
        
        let fileName = "\(Int(x))-\(Int(y)).png"
        let fileURL = outputFolder.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL, options: .atomic)
            print("💾 Saved: \(fileURL.lastPathComponent)")
        } catch {
            print("⚠️ Failed to save \(fileName): \(error)")
        }
        
        x += step
        y += step
        index += 1
        
    }
    
    print("✅ batchCropSquaresFromFull Screenshot finished, total = \(index)")
}

func processDigPNGsInSquaresDirectory() {
    let fm = FileManager.default
    
    // 1️⃣ 找到 ~/Documents/Squares 目录
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    let squaresURL = docsURL.appendingPathComponent("Squares", isDirectory: true)
    
    guard fm.fileExists(atPath: squaresURL.path) else {
        print("❌ Squares folder does not exist: \(squaresURL.path)")
        return
    }
    
    // 2️⃣ 列出目录下所有文件，过滤出以 "dig.png" 结尾的 PNG
    let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
    
    let urls: [URL]
    do {
        urls = try fm.contentsOfDirectory(
            at: squaresURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )
    } catch {
        print("❌ Failed to list Squares folder: \(error)")
        return
    }
    
    let digPNGs = urls.filter { url in
        url.pathExtension.lowercased() == "png" &&
        url.lastPathComponent.lowercased().hasSuffix("dig.png")
    }
    
    guard !digPNGs.isEmpty else {
        print("⚠️ No *dig.png files found in \(squaresURL.path)")
        return
    }
    
    print("🔍 Found \(digPNGs.count) *dig.png files")
    
    // 3️⃣ 逐个处理
    for fileURL in digPNGs {
        autoreleasepool {
            processSingleDigPNG(at: fileURL, outputFolder: squaresURL)
        }
    }
    
    print("✅ processDigPNGsInSquaresDirectory finished")
}

/// 处理单个 xxx_dig.png
private func processSingleDigPNG(at fileURL: URL, outputFolder: URL) {
    // 加载原图
    guard let nsImage = NSImage(contentsOf: fileURL) else {
        print("❌ Cannot load image at \(fileURL.lastPathComponent)")
        return
    }
    
    guard let fullCG = nsImage.cgImage(forProposedRect: nil,
                                       context: nil,
                                       hints: nil) else {
        print("❌ Cannot get CGImage for \(fileURL.lastPathComponent)")
        return
    }
    
    let width  = fullCG.width
    let height = fullCG.height
    
    // 右上角区域尺寸（防止图片过小，取最小值）
    let patchW = min(18, width)
    let patchH = min(22, height)
    
    // 右上角区域在 CG 坐标系（原点在左下）的坐标
    // x: width - patchW, y: height - patchH
    let patchRect = CGRect(
        x: width  - patchW,
        y: height - patchH,
        width: patchW,
        height: patchH
    )
    
    guard let patchCG = fullCG.cropping(to: patchRect) else {
        print("❌ Failed to crop patch from \(fileURL.lastPathComponent)")
        return
    }
    
    // 创建新的位图上下文，绘制原图 + 两个角覆盖
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("❌ Failed to create CGContext for \(fileURL.lastPathComponent)")
        return
    }
    
    let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
    
    // 先画整张原图
    ctx.draw(fullCG, in: fullRect)
    
    // 计算目标位置：
    // 左上角：x = 0, y = height - patchH
    let destTopLeft = CGRect(
        x: 0,
        y: height - patchH,
        width: patchW,
        height: patchH
    )
    
    // 右下角：x = width - patchW, y = 0
    let destBottomRight = CGRect(
        x: width - patchW,
        y: 0,
        width: patchW,
        height: patchH
    )
    
    // 绘制补丁
    ctx.draw(patchCG, in: destTopLeft)
    ctx.draw(patchCG, in: destBottomRight)
    
    // 生成新的 CGImage
    guard let newCG = ctx.makeImage() else {
        print("❌ Failed to create new CGImage for \(fileURL.lastPathComponent)")
        return
    }
    
    let rep = NSBitmapImageRep(cgImage: newCG)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("❌ PNG encode failed for \(fileURL.lastPathComponent)")
        return
    }
    
    // 输出文件名：原文件名去掉扩展 + "_update.png"
    let baseName = fileURL.deletingPathExtension().lastPathComponent
    let newName  = baseName + "_update.png"
    let outURL   = outputFolder.appendingPathComponent(newName)
    
    do {
        try data.write(to: outURL, options: .atomic)
        print("💾 Saved updated image: \(newName)")
    } catch {
        print("❌ Failed to save \(newName): \(error)")
    }
}

/// 处理 ~/Documents/Squares 下所有文件名以 "LT.png" 结尾的 PNG：
/// 1. 取右下角 20x24 区域
/// 2. 旋转 180 度（上下颠倒）
/// 3. 覆盖到左上角
/// 4. 保存为 update_原文件名.png
func processLeftTopPNGsInSquaresDirectory() {
    let fm = FileManager.default
    
    // 1️⃣ ~/Documents
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // ~/Documents/Squares
    let squaresURL = docsURL.appendingPathComponent("Squares", isDirectory: true)
    guard fm.fileExists(atPath: squaresURL.path) else {
        print("❌ Squares folder does not exist: \(squaresURL.path)")
        return
    }
    
    // 2️⃣ 找出所有 *LT.png
    let urls: [URL]
    do {
        urls = try fm.contentsOfDirectory(
            at: squaresURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    } catch {
        print("❌ Failed to list Squares folder: \(error)")
        return
    }
    
    let candidates = urls.filter { url in
        url.pathExtension.lowercased() == "png" &&
        url.lastPathComponent.lowercased().hasSuffix("LT.png")
    }
    
    guard !candidates.isEmpty else {
        print("⚠️ No *LT.png files found in \(squaresURL.path)")
        return
    }
    
    print("🔍 Found \(candidates.count) *LT.png files")
    
    for fileURL in candidates {
        autoreleasepool {
            processSingleLeftTopPNG(at: fileURL, outputFolder: squaresURL)
        }
    }
    
    print("✅ processLeftTopPNGsInSquaresDirectory finished")
}

/// 处理单个 xxx_lefttop.png
func processSingleLeftTopPNG(at fileURL: URL, outputFolder: URL, targetWidth: Int = 34, targetHeight: Int = 48) {
    // 加载原图
    guard let nsImage = NSImage(contentsOf: fileURL) else {
        print("❌ Cannot load image: \(fileURL.lastPathComponent)")
        return
    }
    
    guard let fullCG = nsImage.cgImage(
        forProposedRect: nil,
        context: nil,
        hints: nil
    ) else {
        print("❌ Cannot get CGImage for \(fileURL.lastPathComponent)")
        return
    }
    
    let width  = fullCG.width
    let height = fullCG.height
    
    // 右下角 patch 尺寸（防止图太小）
    let patchW = min(width, targetWidth)
    let patchH = min(height, targetHeight)
    
    // 右下角在 CG 坐标：原点左下
    let patchRect = CGRect(
        x: width - patchW,
        y: 0,
        width: patchW,
        height: patchH
    )
    
    guard let patchCG = fullCG.cropping(to: patchRect) else {
        print("❌ Failed to crop patch from \(fileURL.lastPathComponent)")
        return
    }
    
    // 1️⃣ 先创建一个小画布，把 patch 旋转 180°
    guard let patchCtx = CGContext(
        data: nil,
        width: patchW,
        height: patchH,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("❌ Failed to create patch CGContext")
        return
    }
    
    // 旋转 180°：先平移到右上角，再整体旋转 π
    patchCtx.translateBy(x: CGFloat(patchW), y: CGFloat(patchH))
    patchCtx.rotate(by: .pi)
    patchCtx.draw(patchCG, in: CGRect(x: 0, y: 0, width: patchW, height: patchH))
    
    guard let rotatedPatchCG = patchCtx.makeImage() else {
        print("❌ Failed to create rotated patch image")
        return
    }
    
    // 2️⃣ 在一个新的大图上绘制原图 + 左上角覆盖
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("❌ Failed to create full CGContext for \(fileURL.lastPathComponent)")
        return
    }
    
    let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
    ctx.draw(fullCG, in: fullRect)
    
    // 左上角：x=0，y=height - patchH
    let destTopLeft = CGRect(
        x: 0,
        y: height - patchH,
        width: patchW,
        height: patchH
    )
    
    ctx.draw(rotatedPatchCG, in: destTopLeft)
    
    guard let newCG = ctx.makeImage() else {
        print("❌ Failed to make output CGImage for \(fileURL.lastPathComponent)")
        return
    }
    
    let rep = NSBitmapImageRep(cgImage: newCG)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("❌ PNG encode failed: \(fileURL.lastPathComponent)")
        return
    }
    
    // 输出文件名：update_原文件名.png
    let newName = "update_\(fileURL.lastPathComponent)"
    let outURL = outputFolder.appendingPathComponent(newName)
    
    do {
        try data.write(to: outURL, options: .atomic)
        print("💾 Saved: \(newName)")
    } catch {
        print("❌ Failed to save \(newName): \(error)")
    }
}

func processLTImagesToUpdate() {
    let fm = FileManager.default
    
    // 1️⃣ Documents 目录
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // ~/Documents/Squares/LT
    let squaresURL = docsURL.appendingPathComponent("Squares", isDirectory: true)
    let ltURL = squaresURL.appendingPathComponent("LT", isDirectory: true)
    
    guard fm.fileExists(atPath: ltURL.path) else {
        print("❌ LT folder does not exist: \(ltURL.path)")
        return
    }
    
    // ~/Documents/Squares/Update
    let updateURL = squaresURL.appendingPathComponent("Update", isDirectory: true)
    if !fm.fileExists(atPath: updateURL.path) {
        do {
            try fm.createDirectory(at: updateURL, withIntermediateDirectories: true)
            print("📁 Created Update folder: \(updateURL.path)")
        } catch {
            print("❌ Failed to create Update folder: \(error)")
            return
        }
    }
    
    // 2️⃣ 列出 LT 目录下所有 png 文件
    let urls: [URL]
    do {
        urls = try fm.contentsOfDirectory(
            at: ltURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    } catch {
        print("❌ Failed to list LT folder: \(error)")
        return
    }
    
    let pngFiles = urls.filter { $0.pathExtension.lowercased() == "png" }
    
    guard !pngFiles.isEmpty else {
        print("⚠️ No png files in \(ltURL.path)")
        return
    }
    
    print("🔍 Found \(pngFiles.count) png files in LT")
    
    // 3️⃣ 逐个处理
    for fileURL in pngFiles {
        autoreleasepool {
            processSingleLTImage(at: fileURL, outputFolder: updateURL)
        }
    }
    
    print("✅ processLTImagesToUpdate finished")
}

/// 处理单个 LT png
private func processSingleLTImage(at fileURL: URL, outputFolder: URL) {
    // 加载原图
    guard let nsImage = NSImage(contentsOf: fileURL) else {
        print("❌ Cannot load image: \(fileURL.lastPathComponent)")
        return
    }
    
    guard let fullCG = nsImage.cgImage(
        forProposedRect: nil,
        context: nil,
        hints: nil
    ) else {
        print("❌ Cannot get CGImage for \(fileURL.lastPathComponent)")
        return
    }
    
    let width  = fullCG.width
    let height = fullCG.height
    
    // patch 尺寸（防止图太小）
    let patchW = min(20, width)
    let patchH = min(27, height)
    
    // 右下角区域（CG 坐标原点在左下）
    let patchRect = CGRect(
        x: width - patchW,
        y: 0,
        width: patchW,
        height: patchH
    )
    
    guard let patchCG = fullCG.cropping(to: patchRect) else {
        print("❌ Failed to crop patch from \(fileURL.lastPathComponent)")
        return
    }
    
    // 1️⃣ 旋转 patch 180°
    guard let patchCtx = CGContext(
        data: nil,
        width: patchW,
        height: patchH,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("❌ Failed to create patch CGContext")
        return
    }
    
    // 平移到 (patchW, patchH)，再整体旋转 π
    patchCtx.translateBy(x: CGFloat(patchW), y: CGFloat(patchH))
    patchCtx.rotate(by: .pi)
    patchCtx.draw(patchCG, in: CGRect(x: 0, y: 0, width: patchW, height: patchH))
    
    guard let rotatedPatchCG = patchCtx.makeImage() else {
        print("❌ Failed to create rotated patch")
        return
    }
    
    // 2️⃣ 创建新画布，画原图 + 覆盖左上角
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("❌ Failed to create full CGContext for \(fileURL.lastPathComponent)")
        return
    }
    
    let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
    ctx.draw(fullCG, in: fullRect)
    
    // 左上角：x = 0, y = height - patchH
    let destTopLeft = CGRect(
        x: 0,
        y: height - patchH,
        width: patchW,
        height: patchH
    )
    
    ctx.draw(rotatedPatchCG, in: destTopLeft)
    
    guard let newCG = ctx.makeImage() else {
        print("❌ Failed to make output CGImage for \(fileURL.lastPathComponent)")
        return
    }
    
    let rep = NSBitmapImageRep(cgImage: newCG)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("❌ PNG encode failed: \(fileURL.lastPathComponent)")
        return
    }
    
    // 输出：保持原文件名，保存到 Update 目录
    let outURL = outputFolder.appendingPathComponent(fileURL.lastPathComponent)
    
    do {
        try data.write(to: outURL, options: .atomic)
        print("💾 Saved: \(outURL.lastPathComponent)")
    } catch {
        print("❌ Failed to save \(outURL.lastPathComponent): \(error)")
    }
}
/// 处理 ~/Documents/Squares/RB 下所有 png:
/// 1. 从左上角取 20x27 区域
/// 2. 旋转 180 度
/// 3. 覆盖到右下角
/// 4. 保存到 ~/Documents/Squares/Update 下，文件名不变
func processRBPNGsInSquaresDirectory() {
    let fm = FileManager.default
    
    // 1️⃣ ~/Documents
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // ~/Documents/Squares/RB
    let rbFolder = docsURL
        .appendingPathComponent("Squares", isDirectory: true)
        .appendingPathComponent("RB", isDirectory: true)
    
    guard fm.fileExists(atPath: rbFolder.path) else {
        print("❌ RB folder does not exist: \(rbFolder.path)")
        return
    }
    
    // 2️⃣ 列出 RB 目录下所有 png 文件
    let urls: [URL]
    do {
        urls = try fm.contentsOfDirectory(
            at: rbFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    } catch {
        print("❌ Failed to list RB folder: \(error)")
        return
    }
    
    let pngFiles = urls.filter { $0.pathExtension.lowercased() == "png" }
    
    guard !pngFiles.isEmpty else {
        print("⚠️ No PNG files in \(rbFolder.path)")
        return
    }
    
    print("🔍 Found \(pngFiles.count) PNG files in RB folder")
    
    // 3️⃣ 准备输出目录 ~/Documents/Squares/Update
    let updateFolder = docsURL
        .appendingPathComponent("Squares", isDirectory: true)
        .appendingPathComponent("Update", isDirectory: true)
    
    if !fm.fileExists(atPath: updateFolder.path) {
        do {
            try fm.createDirectory(at: updateFolder, withIntermediateDirectories: true)
            print("📁 Created Update folder: \(updateFolder.path)")
        } catch {
            print("❌ Failed to create Update folder: \(error)")
            return
        }
    }
    
    // 4️⃣ 逐个处理 PNG
    for fileURL in pngFiles {
        autoreleasepool {
            processSingleRBPNG(at: fileURL, outputFolder: updateFolder)
        }
    }
    
    print("✅ processRBPNGsInSquaresDirectory finished")
}

/// 处理单个 RB png：左上取 patch → 旋转 180 → 覆盖右下 → 写入 Update
func processSingleRBPNG(at fileURL: URL, outputFolder: URL, targetwidth: Int = 20, targetHeight: Int = 27) {
    // 加载原图
    guard let nsImage = NSImage(contentsOf: fileURL) else {
        print("❌ Cannot load image: \(fileURL.lastPathComponent)")
        return
    }
    
    guard let fullCG = nsImage.cgImage(forProposedRect: nil,
                                       context: nil,
                                       hints: nil) else {
        print("❌ Cannot get CGImage for \(fileURL.lastPathComponent)")
        return
    }
    
    let width  = fullCG.width
    let height = fullCG.height
    
    // patch 尺寸，避免图片比 20x27 更小
    let patchW = min(targetwidth, width)
    let patchH = min(targetHeight, height)
    
    // 左上角在 CG 坐标（原点左下）：
    // x = 0, y = height - patchH
    let patchRect = CGRect(
        x: 0,
        y: height - patchH,
        width: patchW,
        height: patchH
    )
    
    guard let patchCG = fullCG.cropping(to: patchRect) else {
        print("❌ Failed to crop patch from \(fileURL.lastPathComponent)")
        return
    }
    
    // 1️⃣ 先把 patch 旋转 180°
    guard let patchCtx = CGContext(
        data: nil,
        width: patchW,
        height: patchH,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("❌ Failed to create patch CGContext")
        return
    }
    
    // 实现 180° 旋转：先平移，再旋转 π，然后画原 patch
    patchCtx.translateBy(x: CGFloat(patchW), y: CGFloat(patchH))
    patchCtx.rotate(by: .pi)
    patchCtx.draw(patchCG, in: CGRect(x: 0, y: 0, width: patchW, height: patchH))
    
    guard let rotatedPatchCG = patchCtx.makeImage() else {
        print("❌ Failed to create rotated patch image")
        return
    }
    
    // 2️⃣ 在新的大画布上画原图 + 覆盖右下角
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("❌ Failed to create full CGContext for \(fileURL.lastPathComponent)")
        return
    }
    
    let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
    ctx.draw(fullCG, in: fullRect)
    
    // 右下角：x = width - patchW, y = 0
    let destBottomRight = CGRect(
        x: width - patchW,
        y: 0,
        width: patchW,
        height: patchH
    )
    
    ctx.draw(rotatedPatchCG, in: destBottomRight)
    
    guard let newCG = ctx.makeImage() else {
        print("❌ Failed to make output CGImage for \(fileURL.lastPathComponent)")
        return
    }
    
    let rep = NSBitmapImageRep(cgImage: newCG)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("❌ PNG encode failed: \(fileURL.lastPathComponent)")
        return
    }
    
    // 输出文件名：保持和原文件同名，放到 Update 目录
    let outURL = outputFolder.appendingPathComponent(fileURL.lastPathComponent)
    
    do {
        try data.write(to: outURL, options: .atomic)
        print("💾 Saved updated image: \(outURL.lastPathComponent)")
    } catch {
        print("❌ Failed to save updated image: \(error)")
    }
}

func generateBlackQueenWithYellowBackground() {
    let fm = FileManager.default
    
    // 1️⃣ ~/Documents
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // ~/Documents/Squares
    let squaresURL = docsURL.appendingPathComponent("Squares", isDirectory: true)
    
    let blackURL = squaresURL.appendingPathComponent("blackQueen_needYellow.png")
    let yellowURL = squaresURL.appendingPathComponent("whiteQueen_yellow_rightbottom.png")
    
    // 2️⃣ 加载两张图
    guard let blackNS = NSImage(contentsOf: blackURL) else {
        print("❌ Cannot load \(blackURL.path)")
        return
    }
    guard let yellowNS = NSImage(contentsOf: yellowURL) else {
        print("❌ Cannot load \(yellowURL.path)")
        return
    }
    
    guard let blackCG = blackNS.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let yellowCG = yellowNS.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("❌ Cannot get CGImage from NSImage")
        return
    }
    
    let width  = blackCG.width
    let height = blackCG.height
    
    guard yellowCG.width == width, yellowCG.height == height else {
        print("❌ Image sizes differ, cannot align pixels")
        return
    }
    
    // 3️⃣ 建立两个 RGBA 上下文，绘制黑后与米黄后
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    
    guard let blackCtx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ),
    let yellowCtx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        print("❌ Failed to create CGContext")
        return
    }
    
    let drawRect = CGRect(x: 0, y: 0, width: width, height: height)
    blackCtx.draw(blackCG, in: drawRect)
    yellowCtx.draw(yellowCG, in: drawRect)
    
    guard let blackData = blackCtx.data,
          let yellowData = yellowCtx.data else {
        print("❌ Cannot access bitmap data")
        return
    }
    
    let blackPtr  = blackData.bindMemory(to: UInt8.self, capacity: width * height * 4)
    let yellowPtr = yellowData.bindMemory(to: UInt8.self, capacity: width * height * 4)
    
    let bytesPerRow = blackCtx.bytesPerRow
    let bytesPerPixel = 4
    
    // 4️⃣ 像素级遍历：把「深蓝背景」替换为黄色背景（来自白后图）
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * bytesPerPixel
            
            let r = blackPtr[offset + 0]
            let g = blackPtr[offset + 1]
            let b = blackPtr[offset + 2]
            let a = blackPtr[offset + 3]
            
            if isDarkBlueBackgroundPixel(r: r, g: g, b: b, a: a) {
                // 用 yellow 图中的对应像素替换
                blackPtr[offset + 0] = yellowPtr[offset + 0]
                blackPtr[offset + 1] = yellowPtr[offset + 1]
                blackPtr[offset + 2] = yellowPtr[offset + 2]
                blackPtr[offset + 3] = yellowPtr[offset + 3]
            }
        }
    }
    
    // 5️⃣ 生成新图并写入 ~/Documents/Squares/Update/blackQueen_yellow.png
    guard let outCG = blackCtx.makeImage() else {
        print("❌ Failed to make output CGImage")
        return
    }
    
    let rep = NSBitmapImageRep(cgImage: outCG)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("❌ PNG representation failed")
        return
    }
    
    let updateFolder = squaresURL.appendingPathComponent("Update", isDirectory: true)
    if !fm.fileExists(atPath: updateFolder.path) {
        do {
            try fm.createDirectory(at: updateFolder, withIntermediateDirectories: true)
            print("📁 Created Update folder: \(updateFolder.path)")
        } catch {
            print("❌ Failed to create Update folder: \(error)")
            return
        }
    }
    
    let outURL = updateFolder.appendingPathComponent("blackQueen_yellow.png")
    
    do {
        try pngData.write(to: outURL, options: .atomic)
        print("💾 Saved yellow-background black queen to: \(outURL.path)")
    } catch {
        print("❌ Failed to save blackQueen_yellow.png: \(error)")
    }
}

/// 粗略判断「深蓝背景像素」
/// - 蓝通道明显高于红/绿
/// - 整体偏暗，避免误伤棋子高亮部分
private func isDarkBlueBackgroundPixel(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> Bool {
    if a < 10 { return false }  // 忽略几乎透明
    
    let rf = Int(r)
    let gf = Int(g)
    let bf = Int(b)
    
    let maxRG = max(rf, gf)
    let brightness = (rf + gf + bf) / 3
    
    // 深蓝：蓝明显大于红/绿 & 偏暗
    return bf > 60               // 蓝本身不能太低
        && (bf - maxRG) > 20     // 和红/绿差距明显
        && brightness < 130      // 整体比较暗（背景）
}


/// 从 ~/Documents/Squares/blackKing_needBlue.png 和
/// ~/Documents/Squares/whiteKing_blue_rightbottom.png 生成：
/// ~/Documents/Squares/Update/blackKing_blue.png
func generateBlackKingWithBlueBackground() {
    let fm = FileManager.default
    
    // 1️⃣ ~/Documents
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // ~/Documents/Squares
    let squaresURL = docsURL.appendingPathComponent("Squares", isDirectory: true)
    
    let blackURL = squaresURL.appendingPathComponent("blackKing_needBlue.png")
    let blueURL  = squaresURL.appendingPathComponent("whiteKing_blue_rightbottom.png")
    
    // 2️⃣ 加载两张图
    guard let blackNS = NSImage(contentsOf: blackURL) else {
        print("❌ Cannot load \(blackURL.path)")
        return
    }
    guard let blueNS = NSImage(contentsOf: blueURL) else {
        print("❌ Cannot load \(blueURL.path)")
        return
    }
    
    guard let blackCG = blackNS.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let blueCG  = blueNS.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("❌ Cannot get CGImage from NSImage")
        return
    }
    
    let width  = blackCG.width
    let height = blackCG.height
    
    guard blueCG.width == width, blueCG.height == height else {
        print("❌ Image sizes differ, cannot align pixels")
        return
    }
    
    // 3️⃣ 建立两个 RGBA 上下文，绘制黑 King + 蓝背景 King
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    
    guard let blackCtx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ),
    let blueCtx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        print("❌ Failed to create CGContext")
        return
    }
    
    let drawRect = CGRect(x: 0, y: 0, width: width, height: height)
    blackCtx.draw(blackCG, in: drawRect)
    blueCtx.draw(blueCG, in: drawRect)
    
    guard let blackData = blackCtx.data,
          let blueData  = blueCtx.data else {
        print("❌ Cannot access bitmap data")
        return
    }
    
    let blackPtr = blackData.bindMemory(to: UInt8.self, capacity: width * height * 4)
    let bluePtr  = blueData.bindMemory(to: UInt8.self,  capacity: width * height * 4)
    
    let bytesPerRow   = blackCtx.bytesPerRow
    let bytesPerPixel = 4
    
    // 4️⃣ 像素级遍历：把「浅黄背景」替换为蓝背景图中的对应像素
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * bytesPerPixel
            
            let r = blackPtr[offset + 0]
            let g = blackPtr[offset + 1]
            let b = blackPtr[offset + 2]
            let a = blackPtr[offset + 3]
            
            if isLightYellowBackgroundPixel(r: r, g: g, b: b, a: a) {
                // 用 blue 图中的对应像素替换
                blackPtr[offset + 0] = bluePtr[offset + 0]
                blackPtr[offset + 1] = bluePtr[offset + 1]
                blackPtr[offset + 2] = bluePtr[offset + 2]
                blackPtr[offset + 3] = bluePtr[offset + 3]
            }
        }
    }
    
    // 5️⃣ 生成新图并写入 ~/Documents/Squares/Update/blackKing_blue.png
    guard let outCG = blackCtx.makeImage() else {
        print("❌ Failed to make output CGImage")
        return
    }
    
    let rep = NSBitmapImageRep(cgImage: outCG)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("❌ PNG representation failed")
        return
    }
    
    let updateFolder = squaresURL.appendingPathComponent("Update", isDirectory: true)
    if !fm.fileExists(atPath: updateFolder.path) {
        do {
            try fm.createDirectory(at: updateFolder, withIntermediateDirectories: true)
            print("📁 Created Update folder: \(updateFolder.path)")
        } catch {
            print("❌ Failed to create Update folder: \(error)")
            return
        }
    }
    
    let outURL = updateFolder.appendingPathComponent("blackKing_blue.png")
    
    do {
        try pngData.write(to: outURL, options: .atomic)
        print("💾 Saved blue-background black king to: \(outURL.path)")
    } catch {
        print("❌ Failed to save blackKing_blue.png: \(error)")
    }
}

/// 粗略判断「浅黄背景像素」
/// - R、G 较高，B 明显偏低
/// - 整体偏亮（棋盘米黄）
/// - 避免覆盖棋子本体的深色/高对比区域
private func isLightYellowBackgroundPixel(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> Bool {
    if a < 10 { return false }           // 忽略几乎透明的
    
    let rf = Int(r)
    let gf = Int(g)
    let bf = Int(b)
    
    let brightness = (rf + gf + bf) / 3  // 粗略亮度
    
    // 条件可以根据你的实际截图再微调：
    // 1. 整体比较亮：> 170
    // 2. R、G 明显高于 B（米黄）
    // 3. 与 B 差距 > 15 防止误伤蓝色/暗色区域
    let isBright   = brightness > 170
    let rgHigh     = rf > 180 && gf > 170
    let blueLower  = bf < 180
    let rgMinusB   = (min(rf, gf) - bf) > 15
    
    return isBright && rgHigh && blueLower && rgMinusB
}

/// 截取当前 ChessApp 主窗口的“全屏”内容，并保存为 PNG。
/// 保存路径：~/Documents/ChessApp/Screenshots/ChessApp_yyyyMMdd_HHmmss.png
@MainActor
func captureChessAppFullScreenshot() {
    // 1️⃣ 拿到当前 App 的主窗口和 contentView
    guard let window = NSApp.windows.first,
          let contentView = window.contentView else {
        print("❌ No window or contentView found for capture")
        return
    }
    
    let bounds = contentView.bounds
    
    // 2️⃣ 把整个 contentView 缓存成位图
    guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
        print("❌ bitmapImageRepForCachingDisplay failed")
        return
    }
    rep.size = bounds.size
    contentView.cacheDisplay(in: bounds, to: rep)
    
    // 3️⃣ 转成 PNG Data
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("❌ PNG representation failed")
        return
    }
    
    // 4️⃣ 生成时间戳文件名
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    let ts = formatter.string(from: Date())
    let fileName = "ChessApp_\(ts).png"
    
    // 5️⃣ 组装路径：~/Documents/ChessApp/Screenshots
    let fm = FileManager.default
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    let appFolder = docsURL.appendingPathComponent("ChessApp", isDirectory: true)
    let shotsFolder = appFolder.appendingPathComponent("Screenshots", isDirectory: true)
    
    // 确保目录存在
    if !fm.fileExists(atPath: shotsFolder.path) {
        do {
            try fm.createDirectory(at: shotsFolder,
                                   withIntermediateDirectories: true)
            print("📁 Created folder: \(shotsFolder.path)")
        } catch {
            print("❌ Failed to create Screenshots folder: \(error)")
            return
        }
    }
    
    let fileURL = shotsFolder.appendingPathComponent(fileName)
    
    // 6️⃣ 写入磁盘
    do {
        try pngData.write(to: fileURL, options: .atomic)
        print("💾 Saved ChessApp full screenshot to: \(fileURL.path)")
    } catch {
        print("❌ Failed to save screenshot: \(error)")
    }
}

func sliceBoardInto64Squares() {
    let fm = FileManager.default
    
    // 1. Documents/Chess/Board 路径
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    let boardFolder = docsURL.appendingPathComponent("Chess/Board", isDirectory: true)
    let boardURL = boardFolder.appendingPathComponent("whiteBoard.png")
    
    guard fm.fileExists(atPath: boardURL.path) else {
        print("❌ Cannot find \(boardURL.path)")
        return
    }
    
    // 2. 读取 nsImage 和 CGImage
    guard let nsImage = NSImage(contentsOf: boardURL) else {
        print("❌ Cannot load whiteBoard.png")
        return
    }
    guard let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("❌ Cannot get CGImage from NSImage")
        return
    }
    
    let width = cg.width
    let height = cg.height
    
    guard width == height else {
        print("⚠️ board is not square: width=\(width), height=\(height)")
        return
    }
    
    let side = width             // 正方形
    let cell = side / 8          // 单格尺寸
    print("📐 board \(side)x\(side), cell \(cell)")
    
    // 3. 输出目录 Documents/Chess/Squares/<timestamp>
    let timestamp = DateFormatter.localizedString(
        from: Date(),
        dateStyle: .short,
        timeStyle: .medium
    ).replacingOccurrences(of: "/", with: "-")
     .replacingOccurrences(of: " ", with: "_")
     .replacingOccurrences(of: ":", with: "-")
    
    let squaresRoot = docsURL.appendingPathComponent("Chess/Squares", isDirectory: true)
    let outputFolder = squaresRoot.appendingPathComponent(timestamp, isDirectory: true)
    
    do {
        try fm.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        print("📁 Output: \(outputFolder.path)")
    } catch {
        print("❌ Failed to create output folder: \(error)")
        return
    }
    
    let columns = ["a","b","c","d","e","f","g","h"]
    
    // 4. 切图循环
    for row in 0..<8 {
        for col in 0..<8 {
            let x = col * cell
            let y = row * cell
            let rect = CGRect(x: x, y: y, width: cell, height: cell)
            
            guard let cropped = cg.cropping(to: rect) else { continue }
            let rep = NSBitmapImageRep(cgImage: cropped)
            
            guard let data = rep.representation(using: .png, properties: [:]) else {
                print("⚠️ Failed to generate PNG at row=\(row) col=\(col)")
                continue
            }
            
            let fileName = "\(row+1)\(columns[col]).png"
            let fileURL = outputFolder.appendingPathComponent(fileName)
            
            do {
                try data.write(to: fileURL)
                print("💾 Saved:", fileName)
            } catch {
                print("❌ Failed writing \(fileName): \(error)")
            }
        }
    }
    
    print("✅ Completed slicing 64 squares.")
}
