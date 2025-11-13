//
//  ChessAppApp.swift
//  ChessApp
//
//  Created by stone on 2025/11/13.
//

import ComposableArchitecture
import SwiftUI

@main
struct ChessAppApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(
                store: Store(
                    initialState: HomeState(),
                    reducer: { HomeFeature() }
                )
            )
        }
    }
}
