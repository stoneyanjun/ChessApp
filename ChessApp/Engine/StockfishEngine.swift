//
//  StockfishEngine.swift
//  ChessApp
//
//  Created by stone on 2025/11/5.
//

import Foundation
import ComposableArchitecture

extension DependencyValues {
    var engineClient: EngineClient {
        get { self[EngineClient.self] }
        set { self[EngineClient.self] = newValue }
    }
}

final class StockfishEngine: @unchecked Sendable {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private let queue = DispatchQueue(label: "stockfish.engine.queue", qos: .userInitiated)
    private var continuation: AsyncStream<String>.Continuation?

    func start() async throws {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                guard self.process == nil else {
                    cont.resume()
                    return
                }

                guard let execURL = Bundle.main.url(forResource: "stockfish", withExtension: nil) else {
                    cont.resume(throwing: EngineError.notFound)
                    return
                }

                let process = Process()
                process.executableURL = execURL
                let stdin = Pipe()
                let stdout = Pipe()
                process.standardInput = stdin
                process.standardOutput = stdout

                self.process = process
                self.stdinPipe = stdin
                self.stdoutPipe = stdout

                stdout.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty,
                          let output = String(data: data, encoding: .utf8) else { return }
                    self.continuation?.yield(output)
                }

                do {
                    try process.run()
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func stop() async {
        queue.async {
            self.stdinPipe?.fileHandleForWriting.closeFile()
            self.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            self.process?.terminate()
            self.process = nil
        }
    }

    func send(_ command: String) async throws {
        guard let stdin = stdinPipe else { throw EngineError.notStarted }
        let line = (command + "\n").data(using: .utf8)!
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do {
                    stdin.fileHandleForWriting.write(line)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func outputStream() async throws -> AsyncStream<String> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    enum EngineError: Error {
        case notStarted
        case notFound
    }
}
