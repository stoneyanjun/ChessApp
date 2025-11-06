//
//  GameAction.swift
//  ChessApp
//
//  Created by stone on 2025/11/6.
//

import Foundation
import ComposableArchitecture

/// All user and system actions within a game session
enum GameAction: Equatable, Sendable {
    // Lifecycle
    case onAppear
    case onDisappear
    case resetGame

    // User Interactions
    case squareSelected(Square)
    case userMoved(ChessMove)

    // Engine Integration
    case engineMove(String)
    case engineStarted(Bool)
    case engineError(String)

    // UI Controls
    case toggleBoardFlip
    case toggleSettings(Bool)

    // Error Handling
    case showError(String)
    case dismissError
}
