//
//  GameView.swift
//  ChessApp
//

import SwiftUI
import ComposableArchitecture

struct GameView: View {
    let store: StoreOf<GameFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("ChessApp")
                        .font(.title2).bold()
                    Spacer()
                    Button {
                        viewStore.send(.toggleBoardFlip)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        viewStore.send(.resetGame)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
                .padding(.horizontal)

                Divider()

                // Board
                ChessBoardView(
                    board: viewStore.game.board,
                    isFlipped: viewStore.isBoardFlipped,
                    selectedSquare: viewStore.selectedSquare,
                    highlightSquares: viewStore.highlightSquares
                ) { square in
                    viewStore.send(.squareSelected(square))
                }
                .padding(8)

                // Status bar
                VStack(spacing: 4) {
                    Text(statusText(for: viewStore.game))
                        .font(.headline)

                    if viewStore.engineThinking {
                        ProgressView("Engine thinking…")
                    }
                }

                Spacer()
            }
            .onAppear { viewStore.send(.onAppear) }
            .onDisappear { viewStore.send(.onDisappear) }
            .alert(
                "Error",
                isPresented: viewStore.binding(
                    get: \.showErrorAlert,
                    send: .dismissError
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = viewStore.errorMessage {
                    Text(message)
                }
            }
        }
    }

    private func statusText(for game: GameStatus) -> String {
        switch game.result {
        case .playing:
            return game.turnColor == .white ? "White to move" : "Black to move"
        case .checkmate(let winner):
            return "\(winner == .white ? "White" : "Black") wins by checkmate"
        case .stalemate:
            return "Draw – stalemate"
        case .drawByRepetition:
            return "Draw – repetition"
        case .drawBy50MoveRule:
            return "Draw – 50-move rule"
        case .drawByAgreement:
            return "Draw – by agreement"
        case .resigned(let by):
            return "\(by == .human ? "Human" : "Engine") resigned"
        }
    }
}
