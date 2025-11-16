//
//  BoardState.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation

struct BoardState: Codable, Hashable {
    // board[rank][file]
    // rank 0 = white’s back rank (1st rank)
    // rank 7 = black’s back rank (8th rank)
    var board: [[SquareState]]

    init() {
        self.board = Array(
            repeating: Array(
                repeating: SquareState(
                    pieceColor: .none,
                    pieceKind: .empty,
                    background: .blue
                ), count: 8
            ),
            count: 8
        )
    }
}
