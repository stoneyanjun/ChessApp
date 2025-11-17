//
//  SquareClassifier.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation
import CoreGraphics
import AppKit

/// 负责把 8x8 的小格 CGImage，结合模板，转换成 BoardState（每格一个 SquareState）。
///
/// 输入：
///   - squares: [[CGImage]]，通常来自 DefaultBoardSliceEngine.sliceBoard(...)
///   - templates: [TemplateKey: TemplateDescriptor]，通常来自 DefaultTemplateLoader.loadTemplates(...)
///
/// 输出：
///   - BoardState，其中 board[rank][file] = SquareState(...)
///
/// 约定：
///   - rank 0 = 白方底线（1 排），7 = 黑方底线（8 排）
///   - file 0 = a 列，7 = h 列
protocol BoardSquareClassifierProtocol {
    func classifyBoard(
        _ squares: [[CGImage]],
        using templates: [TemplateKey: TemplateDescriptor]
    ) throws -> BoardState
}

enum BoardSquareClassifierError: Error {
    case emptyTemplates
    case invalidBoardShape
    case preprocessFailed(rank: Int, file: Int, reason: String)
    case noTemplateMatch(rank: Int, file: Int)
}

/// 默认实现：
/// 1. 把每个格子转换成 64x64 灰度向量。
/// 2. 与所有模板做 L2 距离比较，找到最佳匹配模板。
/// 3. 用模板的 TemplateKey → SquareState，写入 BoardState。
final class DefaultBoardSquareClassifier: BoardSquareClassifierProtocol {

    // 必须和 DefaultTemplateLoader.targetSize 保持一致
    private let targetSize: Int = 64

    // MARK: - Public API

    func classifyBoard(
        _ squares: [[CGImage]],
        using templates: [TemplateKey: TemplateDescriptor]
    ) throws -> BoardState {

        guard !templates.isEmpty else {
            throw BoardSquareClassifierError.emptyTemplates
        }

        // 检查 8x8
        guard squares.count == 8, squares.allSatisfy({ $0.count == 8 }) else {
            throw BoardSquareClassifierError.invalidBoardShape
        }

        print("✅ classifyBoard: squares = \(squares.count) x \(squares.first?.count ?? 0)")

        // 为了快速遍历，先把模板字典摊平成数组
        let templateArray: [TemplateDescriptor] = Array(templates.values)

        // 1. 先构造一个空 BoardState
        var boardState = BoardState()
        precondition(boardState.board.count == 8)
        precondition(boardState.board.allSatisfy { $0.count == 8 })

        // 2. 逐格处理
        for rank in 0..<8 {
            for file in 0..<8 {
                let squareImage = squares[rank][file]

                // 2.1 把小格预处理成 64x64 灰度向量
                let features: [Float]
                do {
                    features = try preprocessSquare(squareImage)
                } catch {
                    throw BoardSquareClassifierError.preprocessFailed(
                        rank: rank,
                        file: file,
                        reason: "\(error)"
                    )
                }

                // 2.2 在所有模板中找到距离最小的一个
                guard let best = findBestTemplate(
                    for: features,
                    in: templateArray
                ) else {
                    throw BoardSquareClassifierError.noTemplateMatch(rank: rank, file: file)
                }

                let key = best.key

                // 2.3 用模板的 key → SquareState
                let squareState = SquareState(
                    pieceColor: key.pieceColor,
                    pieceKind: key.pieceKind,
                    background: key.background
                )

                boardState.board[rank][file] = squareState
            }
        }

        return boardState
    }

    // MARK: - Preprocess single square

    /// 把一个棋盘小格 CGImage → 64x64 灰度向量 [Float]，范围 0~1。
    /// 实现与 DefaultTemplateLoader.makeDescriptor 的内部逻辑保持一致。
    private func preprocessSquare(_ image: CGImage) throws -> [Float] {
        let width = targetSize
        let height = targetSize

        guard let colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2) else {
            throw NSError(domain: "SquareClassifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create gray colorspace"])
        }

        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw NSError(domain: "SquareClassifier", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create CGContext"])
        }

        context.interpolationQuality = .high
        let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.draw(image, in: rect)

        guard let data = context.data else {
            throw NSError(domain: "SquareClassifier", code: 3, userInfo: [NSLocalizedDescriptionKey: "Context has no data"])
        }

        let count = width * height
        let buffer = data.bindMemory(to: UInt8.self, capacity: count)
        var vector = [Float](repeating: 0, count: count)

        for i in 0..<count {
            vector[i] = Float(buffer[i]) / 255.0
        }

        return vector
    }

    // MARK: - Template Matching

    /// 在所有模板中找与指定特征向量“距离”最近的模板。
    /// 这里使用简单的 L2 距离（平方和），越小越相似。
    private func findBestTemplate(
        for features: [Float],
        in templates: [TemplateDescriptor]
    ) -> TemplateDescriptor? {

        guard !templates.isEmpty else { return nil }

        var bestTemplate: TemplateDescriptor?
        var bestDistance = Float.greatestFiniteMagnitude

        for tmpl in templates {
            // 长度必须一致
            guard tmpl.grayscaleVector.count == features.count else {
                continue
            }

            var dist: Float = 0
            // 计算 L2 距离的平方（不用开方，比较大小即可）
            for i in 0..<features.count {
                let diff = features[i] - tmpl.grayscaleVector[i]
                dist += diff * diff
                // 可选：如果已经比当前最小值大很多了，可以提前 break
            }

            if dist < bestDistance {
                bestDistance = dist
                bestTemplate = tmpl
            }
        }

        return bestTemplate
    }
}
