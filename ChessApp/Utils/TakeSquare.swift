//
//  TakeSquare.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation
import AppKit
import CoreGraphics


func takeSquare(solution: String) {
    let fm = FileManager.default
    
    // 1. 找到 Documents/ChessApp/(solution)
    guard let docsURL = fm.urls(for: .documentDirectory,
                                in: .userDomainMask).first else {
        print("❌ Cannot locate Documents folder")
        return
    }
    
    let chessAppFolder = docsURL.appendingPathComponent(Constants.chessApp, isDirectory: true)
    let resolutionFolder = chessAppFolder.appendingPathComponent(solution, isDirectory: true)
    let boardFolder = resolutionFolder.appendingPathComponent(Constants.board, isDirectory: true)
    let squareRootFolder = resolutionFolder.appendingPathComponent(Constants.square, isDirectory: true)
    
    // 2. 确保 Square 根目录存在（Documents/ChessApp/(solution)/Square）
    do {
        try fm.createDirectory(at: squareRootFolder,
                               withIntermediateDirectories: true,
                               attributes: nil)
    } catch {
        print("❌ Failed to create square root folder: \(error)")
        return
    }
    
    // 3. 获取 Board 目录下所有 PNG 文件
    let boardPngFiles: [URL]
    do {
        let allFiles = try fm.contentsOfDirectory(at: boardFolder,
                                                  includingPropertiesForKeys: nil,
                                                  options: [.skipsHiddenFiles])
        boardPngFiles = allFiles.filter { $0.pathExtension.lowercased() == "png" }
    } catch {
        print("❌ Failed to list board folder: \(error)")
        return
    }
    
    guard !boardPngFiles.isEmpty else {
        print("⚠️ No PNG board files found in \(boardFolder.path)")
        return
    }
    
    // 4. 逐个棋盘文件切 64 个格子
    for boardURL in boardPngFiles {
        autoreleasepool {
            guard let nsImage = NSImage(contentsOf: boardURL) else {
                print("❌ Cannot load board image: \(boardURL.lastPathComponent)")
                return
            }
            
            guard let cgImage = nsImage.cgImage(forProposedRect: nil,
                                                context: nil,
                                                hints: nil) else {
                print("❌ Cannot get CGImage from: \(boardURL.lastPathComponent)")
                return
            }
            
            let width = cgImage.width
            let height = cgImage.height
            
            // 使用正方形的最小边，避免非正方形导致超出
            let side = min(width, height)
            
            if width != height {
                print("⚠️ Board image is not square (\(width)x\(height)), using side \(side)")
            }
            
            let cellSize = CGFloat(side) / 8.0
            
            let baseName = boardURL.deletingPathExtension().lastPathComponent
            
            // 每个棋盘单独一个子目录：Documents/ChessApp/(solution)/Square/(baseName)/
            let squareFolder = squareRootFolder.appendingPathComponent(baseName, isDirectory: true)
            do {
                try fm.createDirectory(at: squareFolder,
                                       withIntermediateDirectories: true,
                                       attributes: nil)
            } catch {
                print("❌ Failed to create square folder for \(baseName): \(error)")
                return
            }
            
            // 以左下角为 (row=0, col=0)，从下往上，从左往右切 8x8
            for row in 0..<8 {           // y 方向（从下到上）
                for col in 0..<8 {       // x 方向（从左到右）
                    autoreleasepool {
                        let x = CGFloat(col) * cellSize
                        let y = CGFloat(row) * cellSize
                        
                        // 最后一行/列可以用剩余尺寸，防止精度误差
                        let isLastCol = (col == 7)
                        let isLastRow = (row == 7)
                        
                        let w = isLastCol ? CGFloat(side) - x : cellSize
                        let h = isLastRow ? CGFloat(side) - y : cellSize
                        
                        let cropRect = CGRect(x: x, y: y, width: w, height: h)
                        
                        guard let squareCG = cgImage.cropping(to: cropRect) else {
                            print("❌ Failed to crop square row:\(row) col:\(col) for \(baseName)")
                            return
                        }
                        
                        let rep = NSBitmapImageRep(cgImage: squareCG)
                        guard let pngData = rep.representation(using: .png, properties: [:]) else {
                            print("❌ Failed to create PNG data for row:\(row) col:\(col) in \(baseName)")
                            return
                        }
                        
                        // 文件名：square_行列，例如 square_00.png ~ square_77.png
                        let fileName = String(format: "square_%d%d.png", row, col)
                        let outputURL = squareFolder.appendingPathComponent(fileName)
                        
                        do {
                            try pngData.write(to: outputURL, options: .atomic)
                            print("✅ Saved square \(fileName) for board \(baseName)")
                        } catch {
                            print("❌ Failed to write square file \(fileName) for \(baseName): \(error)")
                        }
                    }
                }
            }
        }
    }
}

