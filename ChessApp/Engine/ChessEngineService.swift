//
//  ChessEngineService.swift
//  ChessApp
//
//  Created by stone on 2025/11/6.
//

import Foundation

actor ChessEngineService {
    private let engine = StockfishEngine()
    private var currentMoves: [String] = []

    private var outputContinuation: AsyncStream<String>.Continuation?

    func start() async throws {
        try await engine.start()
        let stream = try await engine.outputStream()
        Task.detached {
            for await line in stream {
                print("ENGINE >> \(line)")
            }
        }

        try await engine.send("uci")
        try await engine.send("isready")
        try await engine.send("setoption name Skill Level value 10") // 0–20
    }

    func stop() async {
        await engine.stop()
    }

    func newGame() async throws {
        currentMoves = []
        try await engine.send("ucinewgame")
        try await engine.send("isready")
    }

    /// Send the player's move (white) and get Stockfish’s reply (black)
    func makePlayerMove(_ move: String) async throws -> String {
        currentMoves.append(move)
        let movesStr = currentMoves.joined(separator: " ")
        try await engine.send("position startpos moves \(movesStr)")
        try await engine.send("go movetime 1000")

        let stream = try await engine.outputStream()
        for await line in stream {
            if let range = line.range(of: "bestmove ") {
                let bestMove = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !bestMove.isEmpty {
                    currentMoves.append(bestMove)
                    return bestMove
                }
            }
        }
        throw EngineError.noBestMove
    }

    enum EngineError: Error {
        case noBestMove
    }
}
