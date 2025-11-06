//
//  GameStatus.swift
//  ChessApp
//
//  Created by stone on 2025/11/4.
//

import Foundation
// Models/GameStatus.swift
// Complete model representing a chess game session
// Phase-1 version (ready for TCA reducer integration)

import Foundation

// MARK: - Core Enums

enum Player: String, Codable, Sendable, Equatable {
    case human
    case engine
}

enum GameResult: Codable, Sendable, Equatable {
    case playing
    case checkmate(winner: PieceColor)
    case stalemate
    case drawByRepetition
    case drawBy50MoveRule
    case drawByAgreement
    case resigned(by: Player)
}

// MARK: - Engine Evaluation (optional metadata)
// existing definition earlier in the file …
struct EngineEvaluation: Codable, Sendable, Equatable {
    var centipawns: Int?
    var mateIn: Int?
    var principalVariation: [ChessMove]

    init(centipawns: Int? = nil, mateIn: Int? = nil, principalVariation: [ChessMove] = []) {
        self.centipawns = centipawns
        self.mateIn = mateIn
        self.principalVariation = principalVariation
    }
}

// MARK: - Game Configuration (static or persisted settings)

struct GameConfig: Codable, Sendable, Equatable {
    var searchDepth: Int
    var skillLevel: Int
    var moveTimeMs: Int
    var humanPlaysWhite: Bool

    init(
        searchDepth: Int = 12,
        skillLevel: Int = 10,
        moveTimeMs: Int = 0,
        humanPlaysWhite: Bool = true
    ) {
        self.searchDepth = searchDepth
        self.skillLevel = skillLevel
        self.moveTimeMs = moveTimeMs
        self.humanPlaysWhite = humanPlaysWhite
    }
}

// MARK: - Main Model

struct GameStatus: Codable, Sendable, Equatable {
    // Core board and player state
    var board: ChessBoard
    var turnColor: PieceColor             // whose turn on the board (white/black)
    var activePlayer: Player              // human or engine controlling that color

    // Game progress
    var moveHistory: [ChessMove]
    var lastMove: ChessMove?
    var result: GameResult

    // Engine metadata
    var engineThinking: Bool
    var engineReady: Bool
    var evaluation: EngineEvaluation?

    // Configuration and errors
    var config: GameConfig
    var errorMessage: String?

    // Derived metrics
    var plyCount: Int { moveHistory.count }

    // MARK: - Initialization
    init(
        board: ChessBoard = .initial(),
        turnColor: PieceColor = .white,
        activePlayer: Player = .human,
        moveHistory: [ChessMove] = [],
        lastMove: ChessMove? = nil,
        result: GameResult = .playing,
        engineThinking: Bool = false,
        engineReady: Bool = false,
        evaluation: EngineEvaluation? = nil,
        config: GameConfig = .init(),
        errorMessage: String? = nil
    ) {
        self.board = board
        self.turnColor = turnColor
        self.activePlayer = activePlayer
        self.moveHistory = moveHistory
        self.lastMove = lastMove
        self.result = result
        self.engineThinking = engineThinking
        self.engineReady = engineReady
        self.evaluation = evaluation
        self.config = config
        self.errorMessage = errorMessage
    }
}

// MARK: - Helpers and Mutations
extension GameStatus {

    /// Reset to a fresh start position
    mutating func reset() {
        board = .initial()
        turnColor = .white
        activePlayer = config.humanPlaysWhite ? .human : .engine
        moveHistory.removeAll()
        lastMove = nil
        result = .playing
        evaluation = nil
        errorMessage = nil
    }

    /// Apply a move (already validated)
    mutating func apply(_ move: ChessMove) {
        board.applyMove(move)
        lastMove = move
        moveHistory.append(move)

        // Toggle color turn
        turnColor = (turnColor == .white) ? .black : .white
        activePlayer = (activePlayer == .human) ? .engine : .human

        evaluation = nil
        errorMessage = nil
    }

    /// Generate current FEN string for engine
    var fen: String { board.fen() }

    /// Quick status helpers
    var isPlaying: Bool { result == .playing }
    var isHumansTurn: Bool { activePlayer == .human }
}
