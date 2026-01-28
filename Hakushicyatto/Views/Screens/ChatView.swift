//
//  ChatView.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/1/28.
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @StateObject var chatService = ChatService()
    @State private var showDrawing = false
    @State private var showNameInput = false
    @State private var showFilePicker = false
    @State private var messageText = ""
    @State private var pendingSvgs: [SvgAttachment] = []
    @State private var currentMessageId: String?
    @State private var isUploading = false
    @State private var showCopyRoomAlert = false
    
    var body: some View {
        ZStack {
            VStack {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("聊天室")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("房間: \(chatService.room)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .onTapGesture {
                                UIPasteboard.general.string = chatService.room
                                showCopyRoomAlert = true
                            }
                    }
                    
                    Spacer()
                    
                    if chatService.isConnected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("已連線")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("未連線")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Button(action: {
                            chatService.connect()
                        }) {
                            Text("重試")
                                .font(.caption)
                                .padding(.leading, 8)
                        }
                    }
                }
                .padding()
                
                // Error Message
                if let error = chatService.error {
                    VStack {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(8)
                    }
                    .background(Color.orange.opacity(0.1))
                }
                
                // Messages List
                MessageListView(messages: chatService.messages, userName: chatService.userName)
                
                Divider()
                
                // Pending SVGs
                if !pendingSvgs.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(pendingSvgs) { svg in
                                SimpleSVGView(urlString: getFullSVGURL(svg.url))
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(6)
                                .frame(width: 60, height: 60)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .offset(x: 6, y: -6)
                                        .onTapGesture {
                                            pendingSvgs.removeAll { $0.id == svg.id }
                                            if pendingSvgs.isEmpty {
                                                currentMessageId = nil
                                            }
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Input Area
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: { showFilePicker = true }) {
                            Image(systemName: isUploading ? "hourglass" : "paperclip")
                                .font(.system(size: 18))
                                .foregroundColor(isUploading ? .gray : .blue)
                        }
                        .disabled(isUploading)

                        Button(action: { showDrawing = true }) {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                        }
                        
                        TextField("輸入訊息...", text: $messageText)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                        }
                        .disabled((messageText.trimmingCharacters(in: .whitespaces).isEmpty && pendingSvgs.isEmpty) || !chatService.isConnected || isUploading)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.gray.opacity(0.05))
            }
            
            // Drawing Sheet
            if showDrawing {
                DrawingSheet(
                    isPresented: $showDrawing,
                    chatService: chatService,
                    currentMessageId: currentMessageId,
                    setMessageId: { newId in currentMessageId = newId },
                    onSaveSVG: { svg in
                        pendingSvgs.append(svg)
                    }
                )
            }

            if showNameInput {
                NameInputModal(
                    isPresented: $showNameInput,
                    initialName: chatService.userName == "User" ? "" : chatService.userName,
                    onSubmit: { name in
                        chatService.setUserName(name)
                        chatService.connect()
                    }
                )
            }
        }
        .alert("已複製房間碼", isPresented: $showCopyRoomAlert) {
            Button("確定") { }
        }
        .onAppear {
            if chatService.userName == "User" {
                showNameInput = true
            } else {
                chatService.connect()
            }
        }
        .onDisappear {
            chatService.disconnect()
        }
        .sheet(isPresented: $showFilePicker) {
            let svgTypes = [UTType.svg, UTType(filenameExtension: "svg")].compactMap { $0 }
            DocumentPicker(types: svgTypes) { urls in
                Task {
                    await handleImportedFiles(urls)
                }
            }
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        let hasText = !text.isEmpty
        let hasSvgs = !pendingSvgs.isEmpty
        guard hasText || hasSvgs else { return }

        let messageId = currentMessageId ?? UUID().uuidString
        currentMessageId = messageId

        Task {
            await chatService.sendMessage(text, svgs: hasSvgs ? pendingSvgs : nil, messageId: messageId)
            messageText = ""
            pendingSvgs = []
            currentMessageId = nil
        }
    }
    
    @MainActor
    private func handleImportedFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isUploading = true
        var ensuredMessageId = currentMessageId ?? UUID().uuidString
        if currentMessageId == nil {
            currentMessageId = ensuredMessageId
        }
        
        for url in urls {
            let accessible = url.startAccessingSecurityScopedResource()
            defer {
                if accessible { url.stopAccessingSecurityScopedResource() }
            }
            
            do {
                let data = try Data(contentsOf: url)
                let attachment = try await chatService.uploadSVG(
                    data,
                    filename: url.lastPathComponent,
                    messageId: ensuredMessageId
                )
                pendingSvgs.append(attachment)
            } catch {
                print("❌ 無法匯入 \(url.lastPathComponent): \(error)")
            }
        }
        
        isUploading = false
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool
    @State private var expandedMessage = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMe { Spacer(minLength: 12) }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 6) {
                Text(message.user)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isMe ? .blue : .gray)
                
                InlineMessageContent(
                    text: message.content,
                    svgs: message.svgs ?? [],
                    isMe: isMe
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isMe ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                .cornerRadius(16)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isMe ? .trailing : .leading)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !isMe { Spacer(minLength: 12) }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }
    
    private func formatTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SVGMessagesView: View {
    let svgs: [SvgAttachment]
    let expandedMessage: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(svgs, id: \.id) { svg in
                SVGMessageItemView(svg: svg, expandedMessage: expandedMessage)
            }
        }
    }
}

struct SVGMessageItemView: View {
    let svg: SvgAttachment
    let expandedMessage: Bool
    
    var body: some View {
        VStack {
            let fullURL = getFullSVGURL(svg.url)
            SimpleSVGView(urlString: fullURL)
                .frame(height: expandedMessage ? 120 : 80)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.25)))
            
            Text(svg.filename)
                .font(.caption2)
                .foregroundColor(.gray)
            
            Text(fullURL)
                .font(.caption2)
                .foregroundColor(.blue)
                .lineLimit(1)
        }
    }
}

func getFullSVGURL(_ relativePath: String) -> String {
    // 已是完整 URL
    if relativePath.lowercased().hasPrefix("http://") || relativePath.lowercased().hasPrefix("https://") {
        return relativePath
    }
    
    // 後端回傳若已含 "/api/svg/..."，避免重複拼接
    let normalized = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
    let baseURL = "https://hakushicyatto-backend.doliy4784.workers.dev"
    return baseURL + "/" + normalized
}

// MARK: - Flow Layout for wrapping content
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    // 換行
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                sizes.append(size)
                
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x - spacing)
            }
            
            self.size.height = y + lineHeight
        }
    }
}

struct InlineMessageContent: View {
    let text: String
    let svgs: [SvgAttachment]
    let isMe: Bool
    
    var body: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 8) {
            if !text.isEmpty && svgs.isEmpty {
                // 只有文字，直接顯示
                Text(text)
                    .font(.body)
                    .foregroundColor(isMe ? .primary : .primary)
                    .multilineTextAlignment(isMe ? .trailing : .leading)
            } else if text.isEmpty && !svgs.isEmpty {
                // 只有 SVG
                FlowLayout(spacing: 4) {
                    ForEach(svgs, id: \.id) { svg in
                        SVGInlineView(svg: svg, isMe: isMe)
                    }
                }
            } else if !text.isEmpty && !svgs.isEmpty {
                // 文字和 SVG 都有，混合顯示
                FlowLayout(spacing: 4) {
                    Text(text)
                        .font(.body)
                        .foregroundColor(isMe ? .primary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    ForEach(svgs, id: \.id) { svg in
                        SVGInlineView(svg: svg, isMe: isMe)
                    }
                }
            }
        }
    }
}

struct SVGInlineView: View {
    let svg: SvgAttachment
    let isMe: Bool
    
    var body: some View {
        let fullURL = getFullSVGURL(svg.url)
        SimpleSVGView(urlString: fullURL)
            .frame(width: 40, height: 40)
        }
}

// MARK: - Name Input Modal
struct NameInputModal: View {
    @Binding var isPresented: Bool
    @State private var name: String
    @FocusState private var isFocused: Bool
    var onSubmit: (String) -> Void
    
    init(isPresented: Binding<Bool>, initialName: String, onSubmit: @escaping (String) -> Void) {
        _isPresented = isPresented
        _name = State(initialValue: initialName)
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { }
            
            VStack(spacing: 16) {
                Text("歡迎來到聊天室")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("請輸入您的名稱以開始聊天")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextField("輸入您的名稱...", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { commit() }
                    .frame(minWidth: 240)
                    .padding(.horizontal)
                
                Button(action: commit) {
                    Text("開始聊天")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.2) : Color.blue)
                        .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .white)
                        .cornerRadius(8)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .padding(32)
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isFocused = true } }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: isPresented)
    }
    
    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        isPresented = false
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    var onPick: ([URL]) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        controller.allowsMultipleSelection = true
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { }
    }
}

struct MessageListView: View {
    let messages: [ChatMessage]
    let userName: String
    
    var body: some View {
        if messages.isEmpty {
            VStack {
                Spacer()
                Text("暫無訊息")
                    .foregroundColor(.gray)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, isMe: message.user == userName)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview {
    ChatView()
}