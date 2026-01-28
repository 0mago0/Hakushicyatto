//
//  SVGDisplayView.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/1/28.
//

import SwiftUI
import WebKit

struct SVGDisplayView: UIViewRepresentable {
    let svgData: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { margin: 0; padding: 0; background: white; display: flex; justify-content: center; align-items: center; height: 100vh; }
                svg { max-width: 100%; max-height: 100%; }
            </style>
        </head>
        <body>
            \(svgData)
        </body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
