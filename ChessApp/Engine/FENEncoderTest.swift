// FENEncoderTest.swift
// ChessFENTest

import Foundation

func testFENEncoderWithSyntheticBoard() {
    // 1. 构造一个空棋盘
    var boardState = BoardState()

    // 确保是 8x8
    precondition(boardState.board.count == 8)
    precondition(boardState.board.allSatisfy { $0.count == 8 })

    // 2. 按标准开局摆子（白方在底 rank 0）
    // 白方
    boardState.board[0][0] = SquareState(pieceColor: .white, pieceKind: .rook,   background: .yellow)
    boardState.board[0][1] = SquareState(pieceColor: .white, pieceKind: .knight, background: .blue)
    boardState.board[0][2] = SquareState(pieceColor: .white, pieceKind: .bishop, background: .yellow)
    boardState.board[0][3] = SquareState(pieceColor: .white, pieceKind: .queen,  background: .blue)
    boardState.board[0][4] = SquareState(pieceColor: .white, pieceKind: .king,   background: .yellow)
    boardState.board[0][5] = SquareState(pieceColor: .white, pieceKind: .bishop, background: .blue)
    boardState.board[0][6] = SquareState(pieceColor: .white, pieceKind: .knight, background: .yellow)
    boardState.board[0][7] = SquareState(pieceColor: .white, pieceKind: .rook,   background: .blue)

    for file in 0..<8 {
        boardState.board[1][file] = SquareState(
            pieceColor: .white,
            pieceKind: .pawn,
            background: (file % 2 == 0 ? .blue : .yellow)
        )
    }

    // 黑方
    boardState.board[7][0] = SquareState(pieceColor: .black, pieceKind: .rook,   background: .yellow)
    boardState.board[7][1] = SquareState(pieceColor: .black, pieceKind: .knight, background: .blue)
    boardState.board[7][2] = SquareState(pieceColor: .black, pieceKind: .bishop, background: .yellow)
    boardState.board[7][3] = SquareState(pieceColor: .black, pieceKind: .queen,  background: .blue)
    boardState.board[7][4] = SquareState(pieceColor: .black, pieceKind: .king,   background: .yellow)
    boardState.board[7][5] = SquareState(pieceColor: .black, pieceKind: .bishop, background: .blue)
    boardState.board[7][6] = SquareState(pieceColor: .black, pieceKind: .knight, background: .yellow)
    boardState.board[7][7] = SquareState(pieceColor: .black, pieceKind: .rook,   background: .blue)

    for file in 0..<8 {
        boardState.board[6][file] = SquareState(
            pieceColor: .black,
            pieceKind: .pawn,
            background: (file % 2 == 0 ? .blue : .yellow)
        )
    }

    // 3. 调用 FENEncoder
    let encoder = DefaultFENEncoder()
    do {
        let placement = try encoder.encodePlacementOnly(from: boardState).value
        print("✅ Synthetic FEN placement = \(placement)")
        // 理论上应该是标准开局：
        // rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR
    } catch {
        print("❌ FENEncoder error: \(error)")
    }
}//
//  FENEncoderTest.swift
//  ChessFENTest
//
//  Created by stone on 2025/11/16.
//

