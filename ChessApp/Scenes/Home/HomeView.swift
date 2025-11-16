//
//  HomeView.swift
//  ChessApp
//
//  Created by stone on 2025/11/13.
//

/*
import SwiftUI
import WebKit
import AppKit
import ComposableArchitecture

struct HomeView: View {

    let store: StoreOf<HomeFeature>

    var body: some View {
        WithPerceptionTracking {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // 底层：WebView，全屏
                    WebView(url: store.url)
                        .ignoresSafeArea()

                    // 上层：左侧面板
                    LeftPaneView(
                        isLoading: store.isLoading,
                        errorMessage: store.errorMessage,
                        onBeginTapped: {
                            store.send(.beginButtonTapped)
                        }
                    )
                    .frame(
                        width: 200,
                        height: proxy.size.height,
                        alignment: .topLeading
                    )
                    .ignoresSafeArea(edges: [.top, .bottom])
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .onAppear {
                store.send(.onAppear)
                goFullScreen()
            }
        }
    }

    /// 自动进入全屏
    private func goFullScreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let window = NSApp.windows.first {
                if !window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
        }
    }
}
*/
