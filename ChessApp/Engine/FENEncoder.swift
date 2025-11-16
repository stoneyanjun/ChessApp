//
//  FENEncoder.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation

// MARK: - Errors

enum FENEncoderError: Error {
    /// BoardState.board is not 8×8.
    case invalidBoardDimensions(expectedRanks: Int, expectedFiles: Int)
}

// MARK: - Protocol

/// Encodes a BoardState into a FENString.
protocol FENEncoderProtocol {

    /// Encode board into full FEN string.
    ///
    /// - Parameters:
    ///   - boardState:     8×8 board model.
    ///   - sideToMove:     Which side to move next (.white / .black).
    ///   - castling:       Castling availability, e.g. "KQkq", "-", "KQ".
    ///   - enPassant:      En passant target square, e.g. "e3" or "-".
    ///   - halfmoveClock:  Halfmove clock for fifty-move rule.
    ///   - fullmoveNumber: Fullmove number, starts at 1.
    ///
    /// - Returns: FENString with full FEN.
    func encodeFull(
        from boardState: BoardState,
        sideToMove: PieceColor,
        castling: String,
        enPassant: String,
        halfmoveClock: Int,
        fullmoveNumber: Int
    ) throws -> FENString

    /// Encode only the piece-placement section of FEN (first field),
    /// e.g. "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"
    ///
    /// - Parameter boardState: 8×8 board model.
    /// - Returns: FENString whose `value` is only the placement section.
    func encodePlacementOnly(from boardState: BoardState) throws -> FENString
}

// MARK: - Default Implementation

final class DefaultFENEncoder: FENEncoderProtocol {

    // MARK: - Public API

    func encodeFull(
        from boardState: BoardState,
        sideToMove: PieceColor,
        castling: String,
        enPassant: String,
        halfmoveClock: Int,
        fullmoveNumber: Int
    ) throws -> FENString {

        let placementFEN = try makePlacementSection(from: boardState)

        // side-to-move: white → "w", black → "b"
        let stm: String
        switch sideToMove {
        case .white:
            stm = "w"
        case .black:
            stm = "b"
        case .none:
            // If .none is passed, default to white (caller should normally not use .none here).
            stm = "w"
        }

        let fen = "\(placementFEN) \(stm) \(castling) \(enPassant) \(halfmoveClock) \(fullmoveNumber)"
        return FENString(value: fen)
    }

    func encodePlacementOnly(from boardState: BoardState) throws -> FENString {
        let placementFEN = try makePlacementSection(from: boardState)
        return FENString(value: placementFEN)
    }

    // MARK: - Internal helpers

    /// Generate the piece placement section (first field) of a FEN string.
    ///
    /// Rules:
    /// - Start from rank 8 down to rank 1 (rank 7 → 0).
    /// - For each rank, go file a..h (0..7).
    /// - Consecutive empty squares are compressed as digits, e.g. "3".
    /// - Separate ranks with "/".
    private func makePlacementSection(from boardState: BoardState) throws -> String {
        // Validate 8×8
        guard boardState.board.count == 8,
              boardState.board.allSatisfy({ $0.count == 8 }) else {
            throw FENEncoderError.invalidBoardDimensions(
                expectedRanks: 8,
                expectedFiles: 8
            )
        }

        var rankStrings: [String] = []

        // FEN starts from rank 8 → our rank index 7, down to rank 1 → index 0
        for rank in (0..<8).reversed() {
            let rankSquares = boardState.board[rank]
            var rankFEN = ""
            var emptyCount = 0

            for file in 0..<8 {
                let square = rankSquares[file]

                if let pieceChar = fenChar(for: square) {
                    // Flush accumulated empties, then append piece char
                    if emptyCount > 0 {
                        rankFEN.append(String(emptyCount))
                        emptyCount = 0
                    }
                    rankFEN.append(pieceChar)
                } else {
                    // It's empty
                    emptyCount += 1
                }
            }

            // Flush trailing empties
            if emptyCount > 0 {
                rankFEN.append(String(emptyCount))
            }

            rankStrings.append(rankFEN)
        }

        return rankStrings.joined(separator: "/")
    }

    /// Convert a SquareState to a single FEN character:
    /// - White: "PNBRQK"
    /// - Black: "pnbrqk"
    /// - nil for empty squares
    private func fenChar(for square: SquareState) -> Character? {
        guard square.pieceKind != .empty,
              square.pieceColor != .none else {
            return nil
        }

        let baseChar: Character
        switch square.pieceKind {
        case .pawn:
            baseChar = "p"
        case .knight:
            baseChar = "n"
        case .bishop:
            baseChar = "b"
        case .rook:
            baseChar = "r"
        case .queen:
            baseChar = "q"
        case .king:
            baseChar = "k"
        case .empty:
            return nil
        }

        switch square.pieceColor {
        case .white:
            // White pieces are uppercase
            return Character(String(baseChar).uppercased())
        case .black:
            // Black pieces are lowercase
            return baseChar
        case .none:
            return nil
        }
    }
}
