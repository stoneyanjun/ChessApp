
//
//  ContentView.swift
//  ChessApp
//
//  Created by stone on 2025/11/13.
//

import SwiftUI
import WebKit
import AppKit

struct ContentView: View {

    private let url = URL(string: "https://www.chesskid.com/home")!

    var body: some View {
        WebView(url: url)
            .ignoresSafeArea()
            .onAppear { goFullScreen() }
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

/// SwiftUI 包装 WKWebView（适用于 macOS）
struct WebView: NSViewRepresentable {

    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        print("🧩 makeNSView called")

        // 配置 WKWebView
        let config = WKWebViewConfiguration()

        // ❗ 禁用 WebGL（减少 GPUProcessCrash）
        config.preferences.setValue(false, forKey: "webGLEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        print("🌐 Loading: \(url.absoluteString)")
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        print("🔁 updateNSView")
    }

    /// 导航代理（日志）
    class Coordinator: NSObject, WKNavigationDelegate {

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🚀 didStartProvisionalNavigation: \(webView.url?.absoluteString ?? "nil")")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ didFinish: \(webView.url?.absoluteString ?? "nil")")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ didFailProvisionalNavigation: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ didFail: \(error.localizedDescription)")
        }
    }
}
