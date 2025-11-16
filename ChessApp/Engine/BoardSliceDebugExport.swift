//
//  BoardSliceDebugExport.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

//  BoardSliceDebugExport.swift
//  ChessApp

import Foundation
import CoreGraphics
import AppKit

/// 把 8×8 的方格 CGImage 导出为 PNG，方便肉眼对比
func debugExportSquares(
    _ squares: [[CGImage]],
    to folderName: String = "ChessApp/DebugSquares"
) {
    let fm = FileManager.default
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("❌ debugExportSquares: cannot locate Documents directory")
        return
    }

    let outFolder = docsURL.appendingPathComponent(folderName)
    do {
        try fm.createDirectory(at: outFolder, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("❌ debugExportSquares: failed to create folder \(outFolder.path): \(error)")
        return
    }

    for rank in 0..<squares.count {
        for file in 0..<squares[rank].count {
            let image = squares[rank][file]
            let fileName = "rank\(rank)_file\(file).png"
            let url = outFolder.appendingPathComponent(fileName)

            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(using: .png, properties: [:]) else {
                print("⚠️ debugExportSquares: failed to create PNG for (\(rank),\(file))")
                continue
            }

            do {
                try data.write(to: url)
            } catch {
                print("⚠️ debugExportSquares: failed to write \(fileName): \(error)")
            }
        }
    }

    print("📸 debugExportSquares: exported to \(outFolder.path)")
}
