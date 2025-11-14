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
        
        // 2️⃣ 整屏转 PNG，保存到 ~/Documents/Chess
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
    // 获取可捕获内容（显示器、窗口、App 等）
    let content = try await SCShareableContent.current
    
    // 取宽度最大的显示器作为“主屏”
    guard let display = content.displays.max(by: { $0.width < $1.width }) else {
        print("❌ No display found")
        return nil
    }
    
    // 捕获整个显示器内容（不排除任何窗口）
    let filter = SCContentFilter(display: display, excludingWindows: [])
    
    let config = SCStreamConfiguration()
    config.capturesAudio = false
    config.showsCursor = false
    
    // 保持原始分辨率（point → pixel）
    let pixelScale = CGFloat(filter.pointPixelScale)
    config.width  = Int(filter.contentRect.width  * pixelScale)
    config.height = Int(filter.contentRect.height * pixelScale)
    
    // 一次性截一张 CGImage
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
func savePNGToDocuments(data: Data, fileName: String) {
    let fm = FileManager.default
    
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    // ~/Documents/Chess
    let chessFolder = docsURL.appendingPathComponent("Chess", isDirectory: true)
    
    // 如果 Chess 文件夹不存在，则自动创建
    if !fm.fileExists(atPath: chessFolder.path) {
        do {
            try fm.createDirectory(at: chessFolder,
                                   withIntermediateDirectories: true)
            print("📁 Created folder: \(chessFolder.path)")
        } catch {
            print("❌ Failed to create Chess folder: \(error)")
            return
        }
    }
    
    // 目标文件路径 ~/Documents/Chess/fileName
    let fileURL = chessFolder.appendingPathComponent(fileName)
    
    do {
        try data.write(to: fileURL, options: .atomic)
        print("💾 Saved PNG to: \(fileURL.path)")
    } catch {
        print("❌ Failed to save PNG: \(error)")
    }
}

///////////////////////////////////////////////////////////
// MARK: - 方案 A：在 ROI 内直接检测大矩形（粗棋盘）
///////////////////////////////////////////////////////////

/// 原始的 ROI + 大矩形检测（作为粗定位 + 兜底）
func detectChessBoardRect(in cgImage: CGImage) -> CGRect? {
    let fullW  = CGFloat(cgImage.width)
    let fullH  = CGFloat(cgImage.height)
    let fullCenter = CGPoint(x: fullW / 2, y: fullH / 2)
    
    // 0️⃣ 定义一个“可能包含棋盘的中间区域”：
    //    - 去掉左右各 15%（排除侧边栏和右侧面板的大部分）
    //    - 上下各保留 5% 作为安全边界
    var roiInFull = CGRect(
        x: fullW * 0.15,
        y: fullH * 0.05,
        width: fullW * 0.70,
        height: fullH * 0.90
    ).integral
    
    // 从整屏裁出这个 ROI
    let roiCGImage: CGImage
    if let cropped = cgImage.cropping(to: roiInFull) {
        roiCGImage = cropped
    } else {
        // 裁剪失败就退回到整屏
        roiInFull = CGRect(x: 0, y: 0, width: fullW, height: fullH)
        roiCGImage = cgImage
    }
    
    let roiW = CGFloat(roiCGImage.width)
    let roiH = CGFloat(roiCGImage.height)
    
    // 1️⃣ 在 ROI 上跑 VNDetectRectangles（找大致棋盘区域）
    let request = VNDetectRectanglesRequest()
    request.minimumAspectRatio = 0.8
    request.maximumAspectRatio = 1.2
    request.minimumSize = 0.1           // 在 ROI 内至少 10%
    request.maximumObservations = 30
    request.minimumConfidence = 0.3
    request.quadratureTolerance = 20.0  // 放宽一点角度容差
    
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
            let bb = obs.boundingBox   // [0,1]，原点在左下（ROI 坐标）
            
            // 先换算到 ROI 像素坐标
            let rectInROI = CGRect(
                x: bb.origin.x * roiW,
                y: (1 - bb.origin.y - bb.height) * roiH,
                width: bb.width * roiW,
                height: bb.height * roiH
            )
            
            // 再映射回整屏坐标：加上 roiInFull 的偏移
            let rectInFull = CGRect(
                x: rectInROI.origin.x + roiInFull.origin.x,
                y: rectInROI.origin.y + roiInFull.origin.y,
                width: rectInROI.width,
                height: rectInROI.height
            )
            
            let side = min(rectInFull.width, rectInFull.height)
            
            // 🚫 忽略太小的矩形：棋盘宽高至少需要 ≥ 400
            guard side >= 400 else { continue }
            
            // 只考虑画面中间 60% 范围内的矩形（排除顶部/底部 UI）
            let nx = rectInFull.midX / fullW
            let ny = rectInFull.midY / fullH
            guard nx > 0.2, nx < 0.8, ny > 0.2, ny < 0.8 else { continue }
            
            // ✅ 评分：越大 + 越靠中心越好
            let center = CGPoint(x: rectInFull.midX, y: rectInFull.midY)
            let dist = hypot(center.x - fullCenter.x, center.y - fullCenter.y)
            let score = side - dist * 0.2   // side 权重大，dist 作为惩罚
            
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
            ).integral
            print("🎯 Vision(ROI) detected board rect: \(found)")
            return found
        } else {
            print("⚠️ Vision rectangles found in ROI, but none passed filters")
        }
    } else {
        print("⚠️ Vision found no rectangles in ROI, go to fallback")
    }
    
    // 2️⃣ 兜底：中心裁剪逻辑（可继续微调）
    let minSideRequired: CGFloat = 400
    var side = min(fullW, fullH) * 0.7
    if side < minSideRequired {
        side = min(minSideRequired, min(fullW, fullH))
    }
    
    var originX = (fullW  - side) / 2
    var originY = (fullH - side) / 2
    
    // 棋盘略靠上：上移一点
    originY -= fullH * 0.03
    
    originX = max(0, min(originX, fullW  - side))
    originY = max(0, min(originY, fullH - side))
    
    let fallbackRect = CGRect(x: originX, y: originY, width: side, height: side).integral
    print("🎯 Fallback board rect: \(fallbackRect)")
    return fallbackRect
}

///////////////////////////////////////////////////////////
// MARK: - 方案 B：检测很多“小方格”，反推出棋盘区域
///////////////////////////////////////////////////////////

/// 在 ROI 内检测大量小方格（棋盘单格），
/// 然后用这些小方格的整体包围框，反推出整块棋盘区域。
func detectChessBoardRectBySquares(in cgImage: CGImage) -> CGRect? {
    let fullW  = CGFloat(cgImage.width)
    let fullH  = CGFloat(cgImage.height)
    
    // 0️⃣ 定义和上面一致的 ROI，以复用调参
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
    
    // 1️⃣ 在 ROI 上检测「很多小正方形」
    let request = VNDetectRectanglesRequest()
    request.minimumAspectRatio = 0.9
    request.maximumAspectRatio = 1.1
    request.minimumSize = 0.02          // 在 ROI 内至少 2%
    request.maximumObservations = 128
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
    
    // 2️⃣ 映射回整屏坐标，并过滤
    var candidates: [CGRect] = []
    candidates.reserveCapacity(observations.count)
    
    for obs in observations {
        let bb = obs.boundingBox  // [0,1] in ROI
        
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
        
        // 尺寸范围用相对短边来限制，分辨率无关
        let minCell = min(fullW, fullH) * 0.02   // ~2%
        let maxCell = min(fullW, fullH) * 0.20   // ~20%
        
        guard aspect > 0.9,
              side >= minCell,
              side <= maxCell else {
            continue
        }
        
        // 再约束到中间 70% 区域，避免周边 UI 正方形
        let nx = rectInFull.midX / fullW
        let ny = rectInFull.midY / fullH
        guard nx > 0.15, nx < 0.85, ny > 0.15, ny < 0.85 else {
            continue
        }
        
        candidates.append(rectInFull.integral)
    }
    
    guard !candidates.isEmpty else {
        print("⚠️ Small-rect candidates all filtered out")
        return nil
    }
    
    // 3️⃣ 用这些小方格的整体包围框估算棋盘区域
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
    
    var roughRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    
    // 4️⃣ 适当膨胀一点点，避免裁掉边界
    let expandRatio: CGFloat = 0.08
    let expandX = roughRect.width  * expandRatio
    let expandY = roughRect.height * expandRatio
    
    roughRect = roughRect.insetBy(dx: -expandX, dy: -expandY)
    
    // Clamp 到整屏
    roughRect.origin.x = max(0, roughRect.origin.x)
    roughRect.origin.y = max(0, roughRect.origin.y)
    if roughRect.maxX > fullW  { roughRect.size.width  = fullW  - roughRect.origin.x }
    if roughRect.maxY > fullH { roughRect.size.height = fullH - roughRect.origin.y }
    
    let roughSide = min(roughRect.width, roughRect.height)
    let minSide: CGFloat = 400
    let side = max(roughSide, minSide)
    
    let centerX = roughRect.midX
    let centerY = roughRect.midY
    
    var originX = centerX - side / 2
    var originY = centerY - side / 2
    
    originX = max(0, min(originX, fullW  - side))
    originY = max(0, min(originY, fullH - side))
    
    let boardRect = CGRect(x: originX, y: originY, width: side, height: side).integral
    print("🎯 detectChessBoardRectBySquares → \(boardRect) from \(candidates.count) squares")
    return boardRect
}

///////////////////////////////////////////////////////////
// MARK: - 8×8 网格对齐 + 组合方案入口
///////////////////////////////////////////////////////////

/// 把一个大致棋盘矩形，对齐成：
/// - 正方形
/// - 边长为 8 的整数倍
/// - 边长 ≥ 400
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
    
    // 防止中心越界
    centerX = max(side / 2, min(centerX, imageWidth  - side / 2))
    centerY = max(side / 2, min(centerY, imageHeight - side / 2))
    
    var originX = centerX - side / 2.0
    var originY = centerY - side / 2.0
    
    originX = max(0, min(originX, imageWidth  - side))
    originY = max(0, min(originY, imageHeight - side))
    
    let finalRect = CGRect(x: originX, y: originY, width: side, height: side).integral
    print("🎯 snapRectTo8x8Grid → \(finalRect)")
    return finalRect
}

/// 组合方案入口：
/// 1️⃣ 优先：通过“小方格云”反推棋盘（结构化，适配不同分辨率）
/// 2️⃣ 失败：退回到 ROI 大矩形方案
/// 3️⃣ 最终统一走 8×8 网格对齐，保证可切成 64 格
func detectChessBoardRectWithGrid(in cgImage: CGImage) -> CGRect? {
    // 1️⃣ 先尝试小方格方案
    if let bySquares = detectChessBoardRectBySquares(in: cgImage) {
        let snapped = snapRectTo8x8Grid(bySquares, imageSize: cgImage)
        print("🎯 Board rect from squares + grid: \(snapped)")
        return snapped
    }
    
    // 2️⃣ 如果小方格检测失败，退回到原来的粗检测
    guard let rough = detectChessBoardRect(in: cgImage) else {
        print("❌ detectChessBoardRect returned nil")
        return nil
    }
    
    let snappedFallback = snapRectTo8x8Grid(rough, imageSize: cgImage)
    print("🎯 Board rect from rough + grid: \(snappedFallback)")
    return snappedFallback
}
