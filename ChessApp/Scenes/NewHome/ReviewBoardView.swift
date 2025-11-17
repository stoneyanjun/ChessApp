//
//  ReviewBoardView.swift
//  ChessApp
//
//  Created by stone on 2025/11/17.
//

import SwiftUI
import AppKit

struct ReviewBoardView: View {
    /// 只需要 FEN 的棋子布局部分，比如 "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"
    let fenPlacement: String
    /// 已经加载好的模板
    let templates: [TemplateKey: TemplateDescriptor]
    
    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / 8.0
            
            VStack(spacing: 0) {
                // FEN 从 rank 8 到 rank 1，我们就按 rows[0] 顶行显示
                ForEach(0..<8, id: \.self) { rankIndex in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { fileIndex in
                            ZStack {
                                if let (pieceColor, pieceKind) = pieceAt(rank: rankIndex, file: fileIndex) {
                                    let bg = backgroundFor(rank: rankIndex, file: fileIndex)
                                    let key = TemplateKey(
                                        pieceColor: pieceColor,
                                        pieceKind: pieceKind,
                                        background: bg
                                    )
                                    
                                    if let desc = templates[key] {
                                        templateImage(from: desc)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: cellSize, height: cellSize)
                                            .clipped()
                                    } else {
                                        // 找不到对应模板，用纯色占位
                                        backgroundColor(for: rankIndex, file: fileIndex)
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                } else {
                                    // 空格：使用 empty 模板
                                    let bg = backgroundFor(rank: rankIndex, file: fileIndex)
                                    let emptyKey = TemplateKey(
                                        pieceColor: .none,
                                        pieceKind: .empty,
                                        background: bg
                                    )
                                    if let desc = templates[emptyKey] {
                                        templateImage(from: desc)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: cellSize, height: cellSize)
                                            .clipped()
                                    } else {
                                        backgroundColor(for: rankIndex, file: fileIndex)
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 296, height: 296) // 固定 296x296
        .border(Color.white.opacity(0.4), width: 1)
    }
    
    // MARK: - FEN 解析
    
    /// 解析 FEN 的棋子布局部分，得到 8x8 的棋子字符矩阵（大写白子、小写黑子、nil = 空）
    private var pieceMatrix: [[Character?]] {
        let placementPart = fenPlacement.split(separator: " ").first ?? Substring(fenPlacement)
        let ranks = placementPart.split(separator: "/")
        guard ranks.count == 8 else {
            return Array(repeating: Array(repeating: nil, count: 8), count: 8)
        }
        
        var matrix: [[Character?]] = []
        for rank in ranks {
            var row: [Character?] = []
            for ch in rank {
                if let n = ch.wholeNumberValue {
                    for _ in 0..<n {
                        row.append(nil)
                    }
                } else {
                    row.append(ch)
                }
            }
            if row.count < 8 {
                row.append(contentsOf: Array(repeating: nil, count: 8 - row.count))
            } else if row.count > 8 {
                row = Array(row.prefix(8))
            }
            matrix.append(row)
        }
        return matrix
    }
    
    /// FEN 的第 0 行是 rank 8，我们直接按这个顺序显示（顶行 rank 8）
    private func pieceAt(rank: Int, file: Int) -> (PieceColor, PieceKind)? {
        let rows = pieceMatrix
        guard rank >= 0, rank < 8, file >= 0, file < 8 else { return nil }
        guard let ch = rows[rank][file] else { return nil }
        
        let isWhite = ch.isUppercase
        
        let color: PieceColor = isWhite ? .white : .black
        let lower = Character(ch.lowercased())
        
        let kind: PieceKind
        switch lower {
        case "p": kind = .pawn
        case "n": kind = .knight
        case "b": kind = .bishop
        case "r": kind = .rook
        case "q": kind = .queen
        case "k": kind = .king
        default:
            return nil
        }
        
        return (color, kind)
    }
    
    // MARK: - 背景（蓝 / 黄）
    
    /// 根据棋盘坐标生成背景类型：假设 a1 为深色（blue）
    /// 注意：我们显示时第 0 行是 rank 8，所以要做一次翻转
    private func backgroundFor(rank: Int, file: Int) -> BackgroundKind {
        // 显示用：rank 0 顶行 = rank 8
        // 棋盘坐标（0 = rank1, 7 = rank8）
        let boardRankIndex = 7 - rank
        let boardFileIndex = file
        
        let isDark = (boardRankIndex + boardFileIndex) % 2 == 1
        // 你自己习惯：深色用 blue，浅色用 yellow
        return isDark ? .blue : .yellow
    }
    
    private func backgroundColor(for rank: Int, file: Int) -> Color {
        backgroundFor(rank: rank, file: file) == .blue
        ? Color.blue.opacity(0.6)
        : Color.yellow.opacity(0.6)
    }
    
    // MARK: - 模板转 SwiftUI Image
    private func templateImage(from desc: TemplateDescriptor) -> Image {
        #if os(macOS)
        let nsImage = NSImage(cgImage: desc.cgImage, size: .zero)
        return Image(nsImage: nsImage)
        #else
        let uiImage = UIImage(cgImage: desc.cgImage)
        return Image(uiImage: uiImage)
        #endif
    }
}
