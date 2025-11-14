//
//  HomeFeature.swift
//  ChessApp
//
//  Created by stone on 2025/11/14.
//

import Foundation
import ComposableArchitecture
import AppKit
import CoreGraphics

struct HomeFeature: Reducer {
    typealias State = HomeState
    typealias Action = HomeAction
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isLoading = false
            state.errorMessage = nil
            return .none
            
        case .beginButtonTapped:
            state.isLoading = true
            state.errorMessage = nil
            
            // 👉 这里触发截图（中心正方形）
            return .run { send in
                // 先在 MainActor 上做截图，拿到 Result
                let result: Result<Data, CaptureError> = await MainActor.run {
                    if let data = captureSquareFromMainWindow(startX: 1152,
                    startY: 158,
                    squareSide: 1328) {
                        return .success(data)
                    } else {
                        return .failure(.captureFailed)
                    }
                }
                // 再把结果发回 TCA
                await send(.captureCompleted(result))
            }
            
        case .webViewDidFinishLoading:
            state.isLoading = false
            state.errorMessage = nil
            return .none
            
        case let .webViewFailed(message):
            state.isLoading = false
            state.errorMessage = message
            return .none
            
        case let .captureCompleted(result):
            state.isLoading = false
            switch result {
            case let .success(data):
                state.lastCaptureImageData = data
                state.errorMessage = nil
            case let .failure(error):
                state.lastCaptureImageData = nil
                switch error {
                case .noWindow:
                    state.errorMessage = "No active window to capture."
                case .captureFailed:
                    state.errorMessage = "Capture center area failed."
                }
            }
            return .none
        }
    }
}

/// 保存到 ~/Documents/center_capture.png
private func saveCaptureToDocuments(data: Data) {
    let fm = FileManager.default
    
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    let fileURL = docsURL.appendingPathComponent("center_capture.png")
    
    do {
        try data.write(to: fileURL, options: .atomic)
        print("💾 Saved capture to Documents folder: \(fileURL.path)")
    } catch {
        print("❌ Failed to save capture image: \(error)")
    }
}

@MainActor
private func captureSquareFromMainWindow(
    startX: CGFloat,
    startY: CGFloat,
    squareSide: CGFloat
) -> Data? {
    // 1. 主窗口 & contentView
    guard let window = NSApp.windows.first,
          let contentView = window.contentView else {
        print("❌ No window/contentView found")
        return nil
    }
    
    let bounds = contentView.bounds  // view 坐标（points）
    
    // 将视图缓存成位图
    guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
        print("❌ bitmapImageRepForCachingDisplay failed")
        return nil
    }
    rep.size = bounds.size
    contentView.cacheDisplay(in: bounds, to: rep)
    
    // 获取整张截图的 CGImage
    guard let fullImage = rep.cgImage else {
        print("❌ Cannot get cgImage")
        return nil
    }
    
    let fullW = CGFloat(fullImage.width)
    let fullH = CGFloat(fullImage.height)
    
    // 2. Clamp，避免越界
    let clampedSide = min(squareSide, fullW - startX, fullH - startY)
    if clampedSide <= 0 {
        print("❌ Invalid crop area, out of bounds")
        return nil
    }
    
    let cropRect = CGRect(
        x: startX,
        y: startY,
        width: clampedSide,
        height: clampedSide
    )
    
    // 3. 裁剪
    guard let cropped = fullImage.cropping(to: cropRect) else {
        print("❌ Cannot crop")
        return nil
    }
    
    let croppedRep = NSBitmapImageRep(cgImage: cropped)
    
    guard let data = croppedRep.representation(using: .png, properties: [:]) else {
        print("❌ PNG encode failed")
        return nil
    }
    
    print("✅ Cropped square: \(Int(clampedSide)) x \(Int(clampedSide)) starting at (\(Int(startX)),\(Int(startY)))")
    
    // 4. 保存到 Documents 文件夹
    saveCaptureToDocuments(data: data)
    
    return data
}
