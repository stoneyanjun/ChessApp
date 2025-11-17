//
//  BoardState+FENEncoder.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation


// MARK: - FEN Types & Errors

/// 仅代表 FEN 的“布局”字段（第一个字段）
/// 例如： "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"
struct FENPlacement {
    let value: String
}

/// FEN 编码错误
enum FENEncoderError: Error {
    case invalidBoardShape
}

/// 协议：只关心“布局”部分；后面 side to move / castling 等可扩展
protocol FENEncoderProtocol {
    func encodePlacementOnly(from state: BoardState) throws -> FENPlacement
    func encodeFullFEN(from state: BoardState) throws -> String
}

// MARK: - DefaultFENEncoder

final class DefaultFENEncoder: FENEncoderProtocol {

    // MARK: - Public API

    /// 只生成 FEN 的第一个字段（棋子布局）
    ///
    /// 约定：
    ///   - FEN 从 8 排写到 1 排
    ///   - 我们内部 board[0] = 1 排（白方底线），因此要从 rank 7 → 0 遍历
    func encodePlacementOnly(from state: BoardState) throws -> FENPlacement {
        // 检查 8x8
        guard state.board.count == 8, state.board.allSatisfy({ $0.count == 8 }) else {
            throw FENEncoderError.invalidBoardShape
        }

        var rows: [String] = []
        rows.reserveCapacity(8)

        // rank 7 (第 8 排，黑方底线) → rank 0 (第 1 排，白方底线)
        for rank in stride(from: 7, through: 0, by: -1) {
            let rowSquares = state.board[rank]
            var rowString = ""
            var emptyCount = 0

            for file in 0..<8 {
                let sq = rowSquares[file]

                if sq.isEmptyForFEN {
                    // 空格计数
                    emptyCount += 1
                } else {
                    // 把之前累积的空格写出去
                    if emptyCount > 0 {
                        rowString.append("\(emptyCount)")
                        emptyCount = 0
                    }

                    // 写棋子字母
                    let c = fenChar(for: sq)
                    rowString.append(c)
                }
            }

            // 这一排结束时，如果还有空格没写，补上
            if emptyCount > 0 {
                rowString.append("\(emptyCount)")
            }

            rows.append(rowString)
        }

        let placement = rows.joined(separator: "/")
        return FENPlacement(value: placement)
    }

    /// 可选：生成完整 FEN：
    ///   <placement> <side> <castling> <enpassant> <halfmove> <fullmove>
    ///
    /// 例如：
    ///   "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    func encodeFullFEN(from state: BoardState) throws -> String {
        let placement = try encodePlacementOnly(from: state).value

        let side: String = (state.sideToMove == .white ? "w" :
                           (state.sideToMove == .black ? "b" : "w"))

        let castling = state.castlingRights.isEmpty ? "-" : state.castlingRights
        let enPassant = state.enPassantTarget
        let halfmove = state.halfmoveClock
        let fullmove = max(state.fullmoveNumber, 1)

        return "\(placement) \(side) \(castling) \(enPassant) \(halfmove) \(fullmove)"
    }

    // MARK: - Helpers

    /// 把一个格子转换成 FEN 棋子字符：
    ///   - 白方：大写 PNBRQK
    ///   - 黑方：小写 pnbrqk
    ///   - 空格不会调用到这里（在 encodePlacementOnly 里已处理）
    private func fenChar(for square: SquareState) -> Character {
        let letter: Character

        switch square.pieceKind {
        case .pawn:
            letter = "p"
        case .knight:
            letter = "n"
        case .bishop:
            letter = "b"
        case .rook:
            letter = "r"
        case .queen:
            letter = "q"
        case .king:
            letter = "k"
        case .empty:
            // 理论上不该来到这里，如果来了就当空格处理
            return "1"
        }

        switch square.pieceColor {
        case .white:
            // 白方大写
            return Character(letter.uppercased())
        case .black:
            // 黑方小写
            return letter
        case .none:
            // 颜色 none 视为空格；理论上不应该来到这里
            return "1"
        }
    }
}
