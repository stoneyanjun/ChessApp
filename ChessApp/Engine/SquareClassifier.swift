//
//  SquareClassifier.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation
import CoreGraphics
import AppKit

// MARK: - Errors

enum SquareClassifierError: Error {
    /// No suitable template found (e.g. all similarities are too low).
    case noMatch(String)

    /// The template dictionary is empty or missing required templates.
    case templatesNotAvailable

    /// Preprocessing of the input square image failed.
    case preprocessingFailed(String)

    /// Board shape is not 8×8.
    case invalidBoardDimensions
}

// MARK: - Protocols

/// Classifies a single square image using preloaded templates.
protocol SquareClassifierProtocol {

    /// Classify a single square image into a SquareState.
    ///
    /// - Parameters:
    ///   - squareImage:  The CGImage representing one board square.
    ///   - templates:    Dictionary of all template descriptors,
    ///                   keyed by TemplateKey.
    ///
    /// - Returns: A SquareState describing the contents of the square.
    /// - Throws:
    ///   - SquareClassifierError.templatesNotAvailable
    ///   - SquareClassifierError.preprocessingFailed
    ///   - SquareClassifierError.noMatch
    func classifySquare(
        _ squareImage: CGImage,
        using templates: [TemplateKey: TemplateDescriptor]
    ) throws -> SquareState
}

/// Classifies an entire 8×8 board of square images into a BoardState.
///
/// This is a convenience layer built on top of `SquareClassifierProtocol`.
protocol BoardSquareClassifierProtocol {

    /// Classify the full board of squares.
    ///
    /// - Parameters:
    ///   - squareImages: 8×8 array of CGImage, indexed [rank][file]
    ///   - templates:    Dictionary of all template descriptors.
    ///
    /// - Returns: A BoardState with 8×8 SquareState.
    func classifyBoard(
        _ squareImages: [[CGImage]],
        using templates: [TemplateKey: TemplateDescriptor]
    ) throws -> BoardState
}

// MARK: - Default per-square classifier

/// Default implementation for classifying a single square.
///
/// Strategy:
/// 1. Preprocess the square image (resize → grayscale vector).
/// 2. Determine background kind (blue / yellow / previous),
///    preferably by comparing with empty_* templates.
/// 3. Filter templates to that background kind.
/// 4. Compute cosine similarity with each candidate.
/// 5. Take best match:
///    - If it's an empty_* template → empty square.
///    - Else → pieceColor + pieceKind from TemplateKey.
final class DefaultSquareClassifier: SquareClassifierProtocol {

    // Use same size as TemplateLoader
    private let targetWidth: Int = 64
    private let targetHeight: Int = 64

    /// Similarity threshold; if best similarity below此值，可以视为 noMatch。
    /// 你可以根据实际效果调整，比如 0.7, 0.8 等。
    private let similarityThreshold: Float = 0.0   // 先设为 0，避免过早 noMatch

    // MARK: - Public API

    func classifySquare(
        _ squareImage: CGImage,
        using templates: [TemplateKey: TemplateDescriptor]
    ) throws -> SquareState {

        guard !templates.isEmpty else {
            throw SquareClassifierError.templatesNotAvailable
        }

        // 1. Preprocess input square to grayscale vector
        let (_, _, squareVector) = try preprocessSquareImage(squareImage)

        // 2. Infer background kind using empty_* templates if possible
        let background = inferBackgroundKind(
            squareVector: squareVector,
            templates: templates
        )

        // 3. Filter templates to same background kind
        let candidateTemplates = templates.values.filter {
            $0.key.background == background
        }

        guard !candidateTemplates.isEmpty else {
            // 如果没有同背景模板，退化为全部模板匹配
            return try classifyUsingAllTemplates(
                squareVector: squareVector,
                templates: Array(templates.values)
            )
        }

        // 4. Compare with candidate templates
        var bestTemplate: TemplateDescriptor?
        var bestScore: Float = -Float.greatestFiniteMagnitude

        for tmpl in candidateTemplates {
            let score = similarity(
                between: squareVector,
                and: tmpl.grayscaleVector
            )
            if score > bestScore {
                bestScore = score
                bestTemplate = tmpl
            }
        }

        guard let chosen = bestTemplate else {
            throw SquareClassifierError.noMatch("No candidate template found")
        }

        if bestScore < similarityThreshold {
            // 根据阈值判断是否认为匹配失败
            throw SquareClassifierError.noMatch(
                "Best similarity \(bestScore) below threshold \(similarityThreshold)"
            )
        }

        // 5. Interpret TemplateKey → SquareState
        let key = chosen.key

        if key.pieceKind == .empty || key.pieceColor == .none {
            // 空格
            return SquareState(
                pieceColor: .none,
                pieceKind: .empty,
                background: key.background
            )
        } else {
            return SquareState(
                pieceColor: key.pieceColor,
                pieceKind: key.pieceKind,
                background: key.background
            )
        }
    }

    // MARK: - Fallback: use all templates (no background-filter)

    private func classifyUsingAllTemplates(
        squareVector: [Float],
        templates: [TemplateDescriptor]
    ) throws -> SquareState {

        var bestTemplate: TemplateDescriptor?
        var bestScore: Float = -Float.greatestFiniteMagnitude

        for tmpl in templates {
            let score = similarity(
                between: squareVector,
                and: tmpl.grayscaleVector
            )
            if score > bestScore {
                bestScore = score
                bestTemplate = tmpl
            }
        }

        guard let chosen = bestTemplate else {
            throw SquareClassifierError.noMatch("No template available")
        }

        if bestScore < similarityThreshold {
            throw SquareClassifierError.noMatch(
                "Best similarity \(bestScore) below threshold \(similarityThreshold)"
            )
        }

        let key = chosen.key
        if key.pieceKind == .empty || key.pieceColor == .none {
            return SquareState(
                pieceColor: .none,
                pieceKind: .empty,
                background: key.background
            )
        } else {
            return SquareState(
                pieceColor: key.pieceColor,
                pieceKind: key.pieceKind,
                background: key.background
            )
        }
    }

    // MARK: - Helpers

    /// Preprocess the input square image into a normalized grayscale vector.
    ///
    /// - Parameter image: Input CGImage (one board square).
    /// - Returns: Tuple of (width, height, grayscaleVector).
    /// - Throws: SquareClassifierError.preprocessingFailed on error.
    func preprocessSquareImage(_ image: CGImage) throws -> (Int, Int, [Float]) {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let width = targetWidth
        let height = targetHeight

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw SquareClassifierError.preprocessingFailed("Failed to create CGContext")
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        context.draw(image, in: rect)

        guard let data = context.data else {
            throw SquareClassifierError.preprocessingFailed("No bitmap data")
        }

        let pixelCount = width * height
        var vector = [Float](repeating: 0, count: pixelCount)
        let buffer = data.bindMemory(to: UInt8.self, capacity: pixelCount)

        for i in 0..<pixelCount {
            vector[i] = Float(buffer[i]) / 255.0
        }

        return (width, height, vector)
    }

    /// Determine the most likely background kind for this square, using empty_* templates if possible.
    ///
    /// - Parameters:
    ///   - squareVector: Preprocessed grayscale vector of the square.
    ///   - templates:    All templates dictionary.
    /// - Returns: A BackgroundKind (blue / yellow / previous).
    func inferBackgroundKind(
        squareVector: [Float],
        templates: [TemplateKey: TemplateDescriptor]
    ) -> BackgroundKind {

        // 1. Collect empty_* templates by background
        var emptyByBackground: [BackgroundKind: [TemplateDescriptor]] = [:]

        for tmpl in templates.values {
            if tmpl.key.pieceKind == .empty && tmpl.key.pieceColor == .none {
                emptyByBackground[tmpl.key.background, default: []].append(tmpl)
            }
        }

        if !emptyByBackground.isEmpty {
            // 2. Compare with empty_* templates and choose best background
            var bestBackground: BackgroundKind = .blue
            var bestScore: Float = -Float.greatestFiniteMagnitude

            for (bg, tmpls) in emptyByBackground {
                for tmpl in tmpls {
                    let score = similarity(
                        between: squareVector,
                        and: tmpl.grayscaleVector
                    )
                    if score > bestScore {
                        bestScore = score
                        bestBackground = bg
                    }
                }
            }

            return bestBackground
        }

        // 3. Fallback heuristic: use average brightness
        // 蓝格一般更暗，黄格更亮，previous 可能更亮一点
        let mean = squareVector.reduce(0, +) / Float(squareVector.count)

        if mean < 0.4 {
            return .blue
        } else if mean < 0.7 {
            return .yellow
        } else {
            return .previous
        }
    }

    /// Compute similarity between two grayscale vectors using cosine similarity.
    ///
    /// Higher value → more similar. Range is roughly [-1, 1], usually [0, 1]
    /// for non-negative vectors.
    ///
    /// If one of the vectors has zero norm, returns -1.
    func similarity(
        between lhs: [Float],
        and rhs: [Float]
    ) -> Float {
        let count = min(lhs.count, rhs.count)
        if count == 0 { return -1.0 }

        var dot: Float = 0
        var normL: Float = 0
        var normR: Float = 0

        for i in 0..<count {
            let a = lhs[i]
            let b = rhs[i]
            dot += a * b
            normL += a * a
            normR += b * b
        }

        let denom = sqrt(normL) * sqrt(normR)
        if denom == 0 {
            return -1.0
        }

        return dot / denom
    }
}

// MARK: - Default board-level classifier

/// Default implementation that uses a `SquareClassifierProtocol`
/// to classify an entire 8×8 board into BoardState.
final class DefaultBoardSquareClassifier: BoardSquareClassifierProtocol {

    private let squareClassifier: SquareClassifierProtocol

    init(squareClassifier: SquareClassifierProtocol = DefaultSquareClassifier()) {
        self.squareClassifier = squareClassifier
    }

    func classifyBoard(
        _ squareImages: [[CGImage]],
        using templates: [TemplateKey: TemplateDescriptor]
    ) throws -> BoardState {

        guard squareImages.count == 8,
              squareImages.allSatisfy({ $0.count == 8 }) else {
            throw SquareClassifierError.invalidBoardDimensions
        }

        var boardState = BoardState()

        for rank in 0..<8 {
            for file in 0..<8 {
                let img = squareImages[rank][file]
                let squareState = try squareClassifier.classifySquare(img, using: templates)
                boardState.board[rank][file] = squareState
            }
        }

        return boardState
    }
}
