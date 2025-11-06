//
//  GameState.swift
//  ChessApp
//
//  Created by stone on 2025/11/6.
//

import Foundation
import ComposableArchitecture

/// State representing the entire chess game session (UI + logic)
struct GameState: Equatable, Sendable {
    var game = GameStatus()
    var isBoardFlipped = false
    var showSettings = false
    var showErrorAlert = false
    var selectedSquare: Square?
    var highlightSquares: [Square] = []
    var engineThinking = false
    var errorMessage: String?
}
