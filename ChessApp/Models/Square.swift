//
//  Square.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation

struct SquareState: Codable, Hashable {
    let pieceColor: PieceColor
    let pieceKind: PieceKind
    let background: BackgroundKind
}
