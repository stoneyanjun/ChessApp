//
//  EngineClient.swift
//  ChessApp
//
//  Created by stone on 2025/11/4.
//

import Foundation
import ComposableArchitecture

struct EngineClient: Sendable {
    var start: @Sendable () async throws -> Void
    var stop: @Sendable () async -> Void
    var sendCommand: @Sendable (String) async throws -> Void
    var readOutput: @Sendable () async throws -> AsyncStream<String>
}

extension EngineClient: DependencyKey {
    static let liveValue: EngineClient = {
        let engine = StockfishEngine()
        return EngineClient(
            start: { try await engine.start() },
            stop: { await engine.stop() },
            sendCommand: { cmd in try await engine.send(cmd) },
            readOutput: { try await engine.outputStream() }
        )
    }()

    static let previewValue = EngineClient(
        start: {},
        stop: {},
        sendCommand: { _ in },
        readOutput: {
            AsyncStream { continuation in
                continuation.yield("bestmove e2e4")
                continuation.finish()
            }
        }
    )
}
