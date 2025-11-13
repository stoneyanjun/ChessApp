//
//  HomeState.swift
//  ChessApp
//
//  Created by stone on 2025/11/14.
//

import Foundation
import ComposableArchitecture
@ObservableState
struct HomeState: Equatable {
    /// 当前要打开的 URL
    var url: URL = URL(string: "https://www.chesskid.com/home")!
    
    /// 加载状态（比如网页或识别中）
    var isLoading: Bool = false
    
    /// 错误信息
    var errorMessage: String?
    
    /// 最近一次截到的中心正方形截图（PNG data）
    var lastCaptureImageData: Data?
}
