//
//  DrawingSheet.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/1/28.
//

import SwiftUI
import PencilKit

struct DrawingSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var chatService: ChatService
    let theme: ChatTheme
    var currentMessageId: String?
    var setMessageId: (String) -> Void
    var onSaveSVG: (SvgAttachment) -> Void
    
    @State private var pkDrawing = PKDrawing()
    @State private var brushWidth: CGFloat = 5
    @State private var isSending = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack {
                // Header
                HStack {
                    Text("手寫板")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("(\(pkDrawing.strokes.count) strokes)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                // Error Message
                if let error = errorMessage {
                    VStack {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(8)
                    }
                    .background(Color.red.opacity(0.1))
                    .padding()
                }
                
                // Canvas
                PKCanvasViewWrapper(drawing: $pkDrawing, lineWidth: $brushWidth)
                    .frame(width: 300, height: 300)
                    .border(Color.gray.opacity(0.3))
                    .onAppear {
                        print("📋 DrawingSheet 已出現")
                    }
                
                // Controls
                VStack(spacing: 12) {
                    // Brush Width Slider
                    HStack {
                        Text("筆寬: \(Int(brushWidth))pt")
                            .font(.caption)
                        Slider(value: $brushWidth, in: 1...20, step: 1)
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: { pkDrawing = PKDrawing() }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("清除")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            print("📤 開始上傳，當前有 \(pkDrawing.strokes.count) 筆劃")
                            Task {
                                await uploadAndContinue()
                            }
                        }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("發送並繼續")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(theme.accent)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .disabled(isSending || pkDrawing.strokes.isEmpty)
                    }
                    .padding()
                }
            }
            
            if isSending {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.35))
            }
        }
        .padding()
        .background(theme.background)
        .cornerRadius(12)
    }
    
    /// 上傳當前筆跡並讓使用者可以繼續寫下一個字
    private func uploadAndContinue() async {
        isSending = true
        errorMessage = nil
        
        let svgData = exportPKDrawingToSVG(pkDrawing, canvasSize: CGSize(width: 300, height: 300))
        print("📝 SVG 數據大小: \(svgData.count) 字節")
        
        let messageId: String = {
            if let existing = currentMessageId {
                return existing
            } else {
                let newId = UUID().uuidString
                DispatchQueue.main.async { setMessageId(newId) }
                return newId
            }
        }()
        
        do {
            let svgDataBytes = svgData.data(using: .utf8) ?? Data()
            print("📤 開始上傳 SVG...")
            
            let svgAttachment = try await chatService.uploadSVG(
                svgDataBytes,
                filename: "handwriting-\(Date().timeIntervalSince1970).svg",
                messageId: messageId
            )
            
            print("✅ SVG 上傳成功，回調返回")
            
            DispatchQueue.main.async {
                onSaveSVG(svgAttachment)
                // 清空畫布以便接續寫下一個字，維持同一則訊息 ID
                pkDrawing = PKDrawing()
                isSending = false
            }
        } catch {
            let errorMsg = "上傳失敗: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            
            DispatchQueue.main.async {
                errorMessage = errorMsg
                isSending = false
            }
        }
    }
}

#Preview {
    DrawingSheet(
        isPresented: .constant(true),
        chatService: ChatService(),
        theme: .classic,
        currentMessageId: nil,
        setMessageId: { _ in },
        onSaveSVG: { _ in }
    )
}
