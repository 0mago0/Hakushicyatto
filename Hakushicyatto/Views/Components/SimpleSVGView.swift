//
//  SimpleSVGView.swift
//  Hakushicyatto
//
//  SVG renderer backed by SVGKit for broader SVG support.
//

import SwiftUI
import UIKit
import SVGKit

struct SimpleSVGView: View {
    let urlString: String
    
    private enum Phase {
        case empty
        case loading
        case success(UIImage)
        case failure
    }
    
    @State private var phase: Phase = .empty
    @State private var lastURL: String?
    @State private var retryCount = 0
    
    private let maxRetries = 5
    
    var body: some View {
        content
            .task {
                // Reload if url changes
                let needsLoad: Bool = {
                    if lastURL != urlString { return true }
                    if case .empty = phase { return true }
                    return false
                }()
                
                if needsLoad {
                    lastURL = urlString
                    phase = .loading
                    retryCount = 0
                    await load()
                }
            }
    }
    
    @ViewBuilder
    private var content: some View {
        switch phase {
        case .empty, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        case .failure:
            VStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("無法加載 SVG")
                    .font(.caption)
                    .foregroundColor(.gray)
                Button {
                    Task {
                        phase = .loading
                        await load()
                    }
                } label: {
                    Text("重試")
                        .font(.caption)
                }
            }
        case .success(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }
    
    // MARK: - Loading
    private func load() async {
        guard let url = URL(string: urlString) else {
            await MainActor.run { phase = .failure }
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try await renderWithSVGKit(data)
            await MainActor.run { retryCount = 0 }
        } catch {
            await scheduleRetry()
        }
    }
    
    @MainActor
    private func renderWithSVGKit(_ data: Data) async throws {
        guard let svgImage = SVGKImage(data: data) else {
            phase = .failure
            return
        }
        
        // Match intrinsic size; fallback to 300x300 if missing
        var targetSize = svgImage.size
        if targetSize.width <= 0 || targetSize.height <= 0 {
            targetSize = CGSize(width: 300, height: 300)
        }
        svgImage.scaleToFit(inside: targetSize)
        
        if let uiImage = svgImage.uiImage {
            phase = .success(uiImage)
        } else {
            phase = .failure
        }
    }
    
    @MainActor
    private func scheduleRetry() async {
        guard retryCount < maxRetries else {
            phase = .failure
            return
        }

        retryCount += 1
        phase = .loading

        // Exponential backoff: 0.3s, 0.6s, 1.2s, 2.4s, 4.8s
        let delaySeconds = pow(2.0, Double(retryCount - 1)) * 0.3
        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        await load()
    }
}
