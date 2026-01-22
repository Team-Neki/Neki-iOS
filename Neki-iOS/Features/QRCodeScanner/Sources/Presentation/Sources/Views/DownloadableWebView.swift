//
//  DownloadableWebView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import SwiftUI
import WebKit

struct DownloadableWebView: UIViewRepresentable {
    let url: URL
    let onDownloadCompleted: (Data) -> Void
    let onError: (Error) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard uiView.url == nil else { return }
        let request = URLRequest(url: url)
        uiView.load(request)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
}


// MARK: - DownloadableWebView + Nested Types

extension DownloadableWebView {
    @MainActor
    final class Coordinator: NSObject {
        let parent: DownloadableWebView
        
        init(parent: DownloadableWebView) { self.parent = parent }
        
        nonisolated func downloadImage(from url: URL) async {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run { parent.onDownloadCompleted(data) }
            } catch {
                await MainActor.run { parent.onError(error) }
            }
        }
    }
}


// MARK: - DownloadableWebView.Coordinator + WKNavigationDelegate

extension DownloadableWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }
        let targetExtensions = ["jpg", "jpeg", "png", "heic", "webp"]
        let fileExtension = url.pathExtension.lowercased()
        
        guard targetExtensions.contains(fileExtension) else { return .allow }
        Task { await downloadImage(from: url) }
        return .cancel
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { parent.onError(error) }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) { parent.onError(error) }
}
