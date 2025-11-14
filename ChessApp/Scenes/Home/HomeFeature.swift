//
//  HomeFeature.swift
//  ChessApp
//
//  Created by stone on 2025/11/14.
//

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
            return .none
            
        case .beginButtonTapped:
            state.isLoading = true
            state.errorMessage = nil
            
            // 1. 全屏截图 → 保存到 Documents
            // 2. 自动检测中间棋盘 → 精确裁剪为正方形 → 也保存到 Documents
            // 3. 棋盘 PNG Data 通过 captureCompleted 回到 state
            return .run { send in
                let result: Result<Data, CaptureError> = await captureFullAndBoardAndSaveToDocuments()
                await send(.captureCompleted(result))
            }
            
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
                }
            }
            return .none
        }
    }
}
