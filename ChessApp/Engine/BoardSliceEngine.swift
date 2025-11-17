//
//  BoardSliceEngine.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation
import CoreGraphics
import AppKit

/// 负责把整张棋盘图片切成 8x8 小格（每格一个 CGImage）
/// - 输入：一张包含完整棋盘的 CGImage，以及可选的 boardRect（棋盘区域像素坐标）
/// - 输出：[[CGImage]]，shape = [8][8]
///   - 第一维 rank：0 = 白方底线（1 排），7 = 黑方底线（8 排）
///   - 第二维 file：0 = a 列，7 = h 列
protocol BoardSliceEngineProtocol {
    /// - Parameters:
    ///   - image: 原始截图或棋盘图
    ///   - boardRect: 棋盘区域在 image 中的坐标（CoreGraphics 坐标：原点在左下）。
    ///                传 nil 时，会在整张图中取最大居中的正方形作为棋盘。
    func sliceBoard(from image: CGImage, boardRect: CGRect?) throws -> [[CGImage]]
}

enum BoardSliceEngineError: Error {
    case invalidBoardRect
    case invalidBoardDimensions(width: Int, height: Int)
    case cannotCropSquare(rank: Int, file: Int)
}

/// 默认实现：把棋盘切成 8x8 个 CGImage
final class DefaultBoardSliceEngine: BoardSliceEngineProtocol {

    // 棋盘固定 8 列 x 8 排
    private let boardSize = 8

    // MARK: - Public API

    func sliceBoard(from image: CGImage, boardRect: CGRect?) throws -> [[CGImage]] {
        let imageWidth = image.width
        let imageHeight = image.height

        guard imageWidth > 0, imageHeight > 0 else {
            throw BoardSliceEngineError.invalidBoardDimensions(width: imageWidth, height: imageHeight)
        }

        // 1. 确定棋盘区域 rect（像素坐标，原点在左下）
        let boardCGRect: CGRect
        if let rect = boardRect {
            // 调用方显式给出棋盘 rect，检查合法性
            let imgRect = CGRect(x: 0, y: 0,
                                 width: CGFloat(imageWidth),
                                 height: CGFloat(imageHeight))
            let inter = rect.intersection(imgRect)
            guard !inter.isNull, inter.width > 0, inter.height > 0 else {
                throw BoardSliceEngineError.invalidBoardRect
            }
            boardCGRect = inter
        } else {
            // 未指定时：取图像中最大的中心正方形
            let side = CGFloat(min(imageWidth, imageHeight))
            let originX = (CGFloat(imageWidth) - side) / 2.0
            let originY = (CGFloat(imageHeight) - side) / 2.0
            boardCGRect = CGRect(x: originX, y: originY, width: side, height: side)
        }

        // 2. 计算每一格的大小（用 Int 避免浮点累积误差）
        let boardWidthPx = Int(boardCGRect.width.rounded())
        let boardHeightPx = Int(boardCGRect.height.rounded())

        guard boardWidthPx > 0, boardHeightPx > 0 else {
            throw BoardSliceEngineError.invalidBoardDimensions(width: boardWidthPx, height: boardHeightPx)
        }

        let cellWidth = boardWidthPx / boardSize
        let cellHeight = boardHeightPx / boardSize

        // 3. 逐格裁剪：rank 从 0..7（底到顶），file 从 0..7（a..h）
        var result: [[CGImage]] = Array(
            repeating: Array(repeating: image, count: boardSize),
            count: boardSize
        )

        for rank in 0..<boardSize {
            for file in 0..<boardSize {
                // CoreGraphics 坐标：原点在左下
                // rank 0 = 白方底线 = boardRect 的最下方
                let x = Int(boardCGRect.origin.x) + file * cellWidth
                let y = Int(boardCGRect.origin.y) + rank * cellHeight

                let rect = CGRect(
                    x: CGFloat(x),
                    y: CGFloat(y),
                    width: CGFloat(cellWidth),
                    height: CGFloat(cellHeight)
                )

                guard let squareCG = image.cropping(to: rect) else {
                    throw BoardSliceEngineError.cannotCropSquare(rank: rank, file: file)
                }

                result[rank][file] = squareCG
            }
        }

        // （可选）调试导出：把 64 个小格输出到 Documents/ChessApp/DebugSquares
        debugExportSquaresIfNeeded(result)

        return result
    }

    // MARK: - Debug Export (optional)

    /// 调试用：把切好的 64 个小格导出到 ~/Documents/ChessApp/DebugSquares
    /// 方便人工检查切图是否正确。
    private func debugExportSquaresIfNeeded(_ squares: [[CGImage]]) {
        // 如果你不想导出，直接注释掉函数体即可。
        let fm = FileManager.default
        guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ debugExportSquares: cannot locate Documents folder")
            return
        }

        let debugFolder = docsURL
            .appendingPathComponent("ChessApp", isDirectory: true)
            .appendingPathComponent("DebugSquares", isDirectory: true)

        do {
            try fm.createDirectory(at: debugFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ debugExportSquares: cannot create folder: \(error)")
            return
        }

        for rank in 0..<squares.count {
            for file in 0..<squares[rank].count {
                let cg = squares[rank][file]
                let rep = NSBitmapImageRep(cgImage: cg)
                guard let data = rep.representation(using: .png, properties: [:]) else {
                    print("❌ debugExportSquares: cannot make PNG for rank \(rank), file \(file)")
                    continue
                }

                // 文件命名：rank0_file0.png 这种
                let filename = "rank\(rank)_file\(file).png"
                let url = debugFolder.appendingPathComponent(filename)

                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    print("❌ debugExportSquares: failed to write \(filename): \(error)")
                }
            }
        }

        print("📸 debugExportSquares: exported to \(debugFolder.path)")
    }
}
