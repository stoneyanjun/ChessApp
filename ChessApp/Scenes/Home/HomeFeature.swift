//
//  HomeFeature.swift
//  ChessApp
//
//  Created by stone on 2025/11/14.
//

/*
import Foundation
import ComposableArchitecture
import AppKit
import CoreGraphics
import ScreenCaptureKit
import Vision

struct HomeFeature: Reducer {
    typealias State = HomeState
    typealias Action = HomeAction
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isLoading = false
            state.errorMessage = nil
//            finalCut64Squares(
//                sourceBoardFolder: "ChessApp/Board/readyBoard",
//                targetSquareFolder: "ChessApp/Square"
//            )
//            testFENEncoderWithSyntheticBoard()
//            generateFENFromCurrentBoard()
            return .none
            
        case .beginButtonTapped:
            state.isLoading = true
            state.errorMessage = nil
            
            generateFENFromCurrentBoard()
//            generateFENFromCurrentBoard()
//            return .run { send in
//                let result: Result<Data, CaptureError> = await captureScreenShot()
//                await send(.captureCompleted(result))
//            }
            
            return .none
        case .webViewDidFinishLoading:
            state.isLoading = false
            state.errorMessage = nil
            return .none
            
        case let .webViewFailed(message):
            state.isLoading = false
            state.errorMessage = message
            return .none
            
        case let .captureCompleted(result):
            state.isLoading = false
            switch result {
            case let .success(data):
                state.lastCaptureImageData = data
                state.errorMessage = nil
            case let .failure(error):
                state.lastCaptureImageData = nil
                switch error {
                case .noWindow:
                    state.errorMessage = "No active window to capture."
                case .captureFailed:
                    state.errorMessage = "Capture center area failed."
                case .saveFailed:
                    state.errorMessage = "Save data failed."
                default:
                    state.errorMessage = "An unknown error occurred."
                }
            }
            return .none
        }
    }
}
*/
