//
//  GameFeature.swift
//  ChessApp
//
//  Created by stone on 2025/11/4.
//

import ComposableArchitecture
import Foundation

nonisolated(unsafe) enum GameFeatureCancelID: Hashable, Sendable {
    case engine
}

@Reducer
struct GameFeature {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.engineClient) var engineClient

    // MARK: Reducer Body
    func reduce(into state: inout GameState, action: GameAction) -> Effect<GameAction> {
        switch action {

        // MARK: Lifecycle
        case .onAppear:
            return .run { send in
                do {
                    let service = ChessEngineService()
                    try await service.start()
                    await send(.engineStarted(true))
                } catch {
                    await send(.engineError("Failed to start engine: \(error.localizedDescription)"))
                }
            }
            .cancellable(id: GameFeatureCancelID.engine)

        case .onDisappear:
            return .cancel(id: GameFeatureCancelID.engine)

        // MARK: Reset
        case .resetGame:
            state.game.reset()
            state.selectedSquare = nil
            state.highlightSquares = []
            state.engineThinking = false
            return .none

        // MARK: User Move
        case let .squareSelected(square):
            if state.selectedSquare == nil {
                state.selectedSquare = square
                state.highlightSquares = []
            } else {
                let move = ChessMove(from: state.selectedSquare!, to: square)
                state.selectedSquare = nil
                state.highlightSquares = []
                return .send(.userMoved(move))
            }
            return .none

        case let .userMoved(move):
            // Human plays white
            state.game.apply(move)
            state.engineThinking = true

            return .run { send in
                let service = ChessEngineService()
                do {
                    try await service.start()
                    let bestMove = try await service.makePlayerMove(move.uci)
                    await send(.engineMove(bestMove))
                } catch {
                    await send(.engineError("Engine error: \(error.localizedDescription)"))
                }
            }

        // MARK: Engine Move
        case let .engineMove(uci):
            state.engineThinking = false
            if let move = ChessMove(uci: uci) {
                state.game.apply(move)
            } else {
                state.errorMessage = "Engine produced invalid move: \(uci)"
                state.showErrorAlert = true
            }
            return .none

        // MARK: UI Actions
        case .toggleBoardFlip:
            state.isBoardFlipped.toggle()
            return .none

        case let .toggleSettings(show):
            state.showSettings = show
            return .none

        // MARK: Errors
        case let .engineError(msg):
            state.engineThinking = false
            state.errorMessage = msg
            state.showErrorAlert = true
            return .none

        case let .showError(msg):
            state.errorMessage = msg
            state.showErrorAlert = true
            return .none

        case .dismissError:
            state.showErrorAlert = false
            state.errorMessage = nil
            return .none

        case .engineStarted:
            return .none
        }
    }
}
