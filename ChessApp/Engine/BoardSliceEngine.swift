//
//  BoardSliceEngine.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation
import CoreGraphics
import AppKit

// MARK: - Errors

enum BoardSliceEngineError: Error {
    /// Provided boardRect is outside the image bounds.
    case boardRectOutOfBounds
    /// Board region cannot be evenly divided into 8×8 squares.
    case invalidBoardGeometry(width: Int, height: Int)
    /// Underlying CGImage operation failed.
    case imageSlicingFailed(String)
}

// MARK: - Protocol

/// Engine that slices a full-board image into 8×8 square images.
///
/// Coordinate convention:
/// - file: 0..7  →  a..h (left to right)
/// - rank: 0..7  →  1..8 (bottom to top, white at rank 0)
///
/// So result[0][0] is a1, result[0][4] is e1, result[7][4] is e8.
protocol BoardSliceEngineProtocol {

    /// Slice a full-board CGImage into 8×8 square images.
    ///
    /// - Parameters:
    ///   - image:     Full chessboard image (or image containing the board).
    ///   - boardRect: Optional rect (in image coordinates) specifying
    ///                where the chessboard lies. If nil, the whole image
    ///                is treated as the board.
    ///
    /// - Returns: 8×8 array of CGImage, indexed as [rank][file].
    /// - Throws: BoardSliceEngineError on invalid geometry or slicing failures.
    func sliceBoard(
        from image: CGImage,
        boardRect: CGRect?
    ) throws -> [[CGImage]]
}

// MARK: - Default Implementation

/// Default implementation for macOS, using CoreGraphics.
/// This class does *no* UI work; it only performs geometric calculations
/// and CGImage cropping.
final class DefaultBoardSliceEngine: BoardSliceEngineProtocol {

    // MARK: - Public API

    func sliceBoard(
        from image: CGImage,
        boardRect: CGRect?
    ) throws -> [[CGImage]] {

        let boardRect = try resolveBoardRect(for: image, requestedRect: boardRect)
        let cellSize = try computeCellSize(from: boardRect)

        // We'll build row-by-row: board[rank][file]
        // rank 0 = bottom (white side), rank 7 = top (black side)
        var board: [[CGImage]] = []

        for rank in 0..<8 {
            var row: [CGImage] = []

            // CGImage origin is top-left, but our rank 0 is bottom.
            // flippedRank 7 means top row in image, 0 means bottom.
            let flippedRank = 7 - rank

            for file in 0..<8 {
                let x = boardRect.minX + CGFloat(file) * cellSize.width
                let y = boardRect.minY + CGFloat(flippedRank) * cellSize.height

                let cropRect = CGRect(
                    x: x,
                    y: y,
                    width: cellSize.width,
                    height: cellSize.height
                )

                guard let square = image.cropping(to: cropRect) else {
                    throw BoardSliceEngineError.imageSlicingFailed(
                        "Failed cropping rank \(rank), file \(file), rect \(cropRect)"
                    )
                }

                row.append(square)
            }

            board.append(row)
        }

        return board
    }

    // MARK: - Helpers

    /// Returns a validated board rect (either the provided one,
    /// or the full image bounds if nil), ensuring it lies inside the image.
    ///
    /// - Throws: BoardSliceEngineError.boardRectOutOfBounds if invalid.
    func resolveBoardRect(
        for image: CGImage,
        requestedRect: CGRect?
    ) throws -> CGRect {

        let fullRect = CGRect(
            x: 0,
            y: 0,
            width: image.width,
            height: image.height
        )

        guard let rect = requestedRect else {
            // If caller doesn't specify, treat whole image as the board
            return fullRect
        }

        // Ensure requested rect is fully inside the image
        if !fullRect.contains(rect) {
            throw BoardSliceEngineError.boardRectOutOfBounds
        }

        return rect
    }

    /// Compute integer cell size from a board rect.
    ///
    /// - Throws: BoardSliceEngineError.invalidBoardGeometry if width/height
    ///           cannot be evenly divided by 8.
    func computeCellSize(from boardRect: CGRect) throws -> CGSize {

        let w = Int(boardRect.width)
        let h = Int(boardRect.height)

        guard w % 8 == 0, h % 8 == 0 else {
            throw BoardSliceEngineError.invalidBoardGeometry(width: w, height: h)
        }

        return CGSize(width: w / 8, height: h / 8)
    }
}
