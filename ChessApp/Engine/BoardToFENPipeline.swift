//
//  BoardToFENPipeline.swift
//  ChessApp
//
//  Created by stone on 2025/11/17.
//


import Foundation
import AppKit
import CoreGraphics

/// 从已经裁剪好的棋盘图片（Documents/ChessApp/<solution>/Board/<current>.png）
/// 通过模板匹配 + FEN 编码，得到当前局面的 FEN（只含棋子布局部分）。
///
/// - Parameters:
///   - solution: 当前分辨率字符串，例如 "3840_2160" 或 "1920_1080"
///   - current:  截图编号，对应 current.png
///
/// - Returns: Result<String, Error>，成功时 value 是 FEN 的 piece-placement 段
func generateFENFromBoard(solution: String, current: Int, templates: [TemplateKey: TemplateDescriptor]) -> Result<String, Error> {
    do {
        let fm = FileManager.default

        // 1️⃣ 定位棋盘图片：~/Documents/ChessApp/<solution>/Board/<current>.png
        guard let docsURL = fm.urls(for: .documentDirectory,
                                    in: .userDomainMask).first else {
            print("❌ Cannot locate Documents directory")
            return .failure(BoardPipelineError.documentsNotFound)
        }

        let chessAppFolder = docsURL.appendingPathComponent(Constants.chessApp, isDirectory: true)
        let resolutionFolder = chessAppFolder.appendingPathComponent(solution, isDirectory: true)
        let boardFolder = resolutionFolder.appendingPathComponent(Constants.board, isDirectory: true)

        let boardFileName = "\(current).png"
        let boardURL = boardFolder.appendingPathComponent(boardFileName)

        guard fm.fileExists(atPath: boardURL.path) else {
            print("❌ Board image not found: \(boardURL.path)")
            return .failure(BoardPipelineError.boardImageNotFound(boardURL))
        }

        guard
            let nsImage = NSImage(contentsOf: boardURL),
            let boardCG = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            print("❌ Failed to load CGImage from \(boardURL.path)")
            return .failure(BoardPipelineError.boardImageDecodeFailed(boardURL))
        }

        print("📂 Using board image = \(boardURL.path)  size = \(boardCG.width)x\(boardCG.height)")

        // 2️⃣ 从 Bundle 载入模板（按分辨率过滤，如 *_3840_2160.png）
        guard let templatesRoot = Bundle.main.resourceURL else {
            print("❌ Cannot locate app bundle resourceURL")
            return .failure(BoardPipelineError.bundleResourcesNotFound)
        }

        if templates.isEmpty {
            print("❌ no templates")
            return .failure(BoardPipelineError.noTemplatesLoadedForResolution(solution))
        }

        // 3️⃣ 切棋盘：8 × 8
        let slicer = DefaultBoardSliceEngine()
        // boardRect: nil → 表示使用整张 boardCG 作为棋盘区域（你前面 takeBoard 已经裁好了）
        let squares = try slicer.sliceBoard(from: boardCG, boardRect: nil)

        guard squares.count == 8, squares.allSatisfy({ $0.count == 8 }) else {
            print("❌ sliceBoard did not produce 8x8 squares, got \(squares.count)x\(squares.first?.count ?? 0)")
            return .failure(BoardPipelineError.invalidSquareGrid)
        }

        print("✅ Sliced board into \(squares.count) ranks × \(squares.first?.count ?? 0) files")

        // 4️⃣ 模板匹配：方格分类 → BoardState
        let classifier = DefaultBoardSquareClassifier()
        let boardState = try classifier.classifyBoard(squares, using: templates)

        print("✅ Classified board into BoardState")
        print("   boardState.board.count = \(boardState.board.count)")
        print("   boardState.board[0].count = \(boardState.board.first?.count ?? 0)")

        // 5️⃣ FEN 编码（只生成 piece-placement 部分）
        let fenEncoder = DefaultFENEncoder()
        let fenPlacement = try fenEncoder.encodePlacementOnly(from: boardState).value

        print("♟ FEN placement = \(fenPlacement)")

        return .success(fenPlacement)

    } catch {
        print("❌ Error in board → FEN pipeline: \(error)")
        return .failure(error)
    }
}

/// 用于描述整条 “棋盘图 → FEN” 流水线中的错误
enum BoardPipelineError: Error {
    case documentsNotFound
    case boardImageNotFound(URL)
    case boardImageDecodeFailed(URL)
    case bundleResourcesNotFound
    case noTemplatesLoadedForResolution(String)
    case invalidSquareGrid
}
