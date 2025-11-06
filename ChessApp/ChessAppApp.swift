//
//  ChessAppApp.swift
//  ChessApp
//
//  Created by stone on 2025/11/4.
//

import SwiftUI
import CoreData
import ComposableArchitecture

@main
struct ChessAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            GameView(
                store: Store(
                    initialState: GameState(),
                    reducer: { GameFeature() }
                )
            )
        }
    }
}
