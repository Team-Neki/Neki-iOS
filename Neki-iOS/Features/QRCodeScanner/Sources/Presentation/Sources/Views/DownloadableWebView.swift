//
//  DownloadableWebView.swift
//  Neki-iOS
//
//  Created by SwainYun on 1/22/26.
//

import SwiftUI
import WebKit
import os

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
        
        func processBlobDownload(url: URL, webView: WKWebView) {
            Logger.presentation.debug("🌐 Blob 다운로드 시작: \(url.absoluteString)")
            
            let script = """
                const targetUrl = targetUrlArg;

                // 1. 유효성 검사 (undefined 체크)
                if (!targetUrl) {
                    throw new Error("Target URL is empty");
                }

                // 2. Blob URL이 아닌 경우에만 절대 경로 변환 시도
                // (blob:http://... 형태는 건드리지 않음)
                let finalUrl = targetUrl;
                if (!targetUrl.startsWith('blob:') && !targetUrl.startsWith('http')) {
                    try {
                        finalUrl = new URL(targetUrl, document.baseURI).href;
                    } catch (e) {
                        console.log("URL parsing failed, using original");
                    }
                }
                
                // 3. 데이터 Fetch
                const response = await fetch(finalUrl);
                
                if (!response.ok) {
                    throw new Error("Fetch Failed Status: " + response.status);
                }
                
                const blob = await response.blob();
                
                // 4. HTML 에러 페이지인지 이중 체크
                // (Blob URL인데 내용물이 HTML인 경우 등 방지)
                if (blob.type.includes("text/html")) {
                    throw new Error("Downloaded content is HTML, not Image (Type: " + blob.type + ")");
                }

                // 5. Base64 변환
                return new Promise((resolve, reject) => {
                    const reader = new FileReader();
                    reader.onloadend = () => resolve(reader.result);
                    reader.onerror = (e) => reject(new Error("FileReader Error: " + e.target.error));
                    reader.readAsDataURL(blob);
                });
            """
            
            webView.callAsyncJavaScript(
                script,
                arguments: ["targetUrlArg": url.absoluteString],
                in: nil,
                in: .page
            ) { [weak self] (result: Result<Any, Error>) in
                guard let self = self else { return }
                
                switch result {
                case .success(let dataAny):
                    guard let dataString = dataAny as? String,
                          let commaIndex = dataString.firstIndex(of: ","),
                          let data = Data(base64Encoded: String(dataString[dataString.index(after: commaIndex)...]))
                    else {
                        Logger.presentation.error("❌ Blob Error: Base64 문자열 변환 실패")
                        return
                    }
                    
                    Logger.presentation.debug("✅ 이미지 데이터 최종 확보 성공 (크기: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))")
                    self.parent.onDownloadCompleted(data)
                    
                case .failure(let error):
                    Logger.presentation.error("❌ Blob 다운로드 실패: \(error.localizedDescription)")
                    
                    let nsError = error as NSError
                    if let jsStack = nsError.userInfo["WKJavaScriptExceptionMessage"] {
                        print("📝 JS 에러 상세: \(jsStack)")
                    }
                    
                    self.parent.onError(error)
                }
            }
        }
    }
}


// MARK: - DownloadableWebView.Coordinator + WKNavigationDelegate

extension DownloadableWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }
        
        if url.scheme == "blob" {
            processBlobDownload(url: url, webView: webView)
            return .cancel
        }
        
        let fileExtension = url.pathExtension.lowercased()
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "webp"]
        let videoExtensions = ["mp4", "mov", "avi", "m4v"]
        
        if imageExtensions.contains(fileExtension) {
            Task { await downloadImage(from: url) }
            return .cancel
        }
        
        if videoExtensions.contains(fileExtension) {
            return .cancel
        }
        
        return .allow
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { parent.onError(error) }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) { parent.onError(error) }
}
