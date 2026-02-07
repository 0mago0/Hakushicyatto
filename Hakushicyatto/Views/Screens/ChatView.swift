//
//  ChatView.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/1/28.
//

import SwiftUI

struct ChatView: View {
    @StateObject var chatService = ChatService()
    @State private var showDrawing = false
    @State private var showNameInput = false
    @State private var showPairingSheet = false
    @State private var showThemePicker = false
    @State private var messageText = ""
    @State private var pendingSvgs: [SvgAttachment] = []
    @State private var currentMessageId: String?
    @State private var showCopyRoomAlert = false
    @AppStorage("chatThemeId") private var chatThemeId: String = ChatTheme.classic.id

    private var theme: ChatTheme {
        ChatTheme.theme(for: chatThemeId)
    }
    
    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("聊天室")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.onBackground)
                        Text("房間: \(chatService.room)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .onTapGesture {
                                UIPasteboard.general.string = chatService.room
                                showCopyRoomAlert = true
                            }
                    }
                    
                    Spacer()
                    
                    Button {
                        showPairingSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.3.group")
                            Text("連線設定")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundColor(theme.onSurface)
                        .background(theme.surface)
                        .cornerRadius(8)
                    }

                    Button {
                        showThemePicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "paintpalette")
                            Text("配色")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundColor(theme.onSurface)
                        .background(theme.surface)
                        .cornerRadius(8)
                    }
                    
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
                MessageListView(messages: chatService.messages, userName: chatService.userName, theme: theme)
                
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
                                .background(theme.surface)
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
                        Button(action: { showDrawing = true }) {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 18))
                                .foregroundColor(theme.accent)
                        }
                        
                        TextField("輸入訊息...", text: $messageText)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .foregroundColor(theme.accent)
                        }
                        .disabled((messageText.trimmingCharacters(in: .whitespaces).isEmpty && pendingSvgs.isEmpty) || !chatService.isConnected)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(theme.surface)
            }
            
            // Drawing Sheet
            if showDrawing {
                DrawingSheet(
                    isPresented: $showDrawing,
                    chatService: chatService,
                    theme: theme,
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
                    theme: theme,
                    initialName: chatService.userName == "User" ? "" : chatService.userName,
                    onSubmit: { name in
                        chatService.setUserName(name)
                        chatService.connect()
                    }
                )
            }
            
            if showPairingSheet {
                PairingSheet(
                    isPresented: $showPairingSheet,
                    chatService: chatService,
                    theme: theme
                )
            }

            if showThemePicker {
                ThemePickerSheet(
                    isPresented: $showThemePicker,
                    selectedThemeId: $chatThemeId
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
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool
    let theme: ChatTheme
    @State private var expandedMessage = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMe { Spacer(minLength: 12) }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 6) {
                Text(message.user)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isMe ? theme.accent : .gray)
                
                HStack(alignment: .bottom) {
                    if isMe {
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    InlineMessageContent(
                        text: message.content,
                        svgs: message.svgs ?? [],
                        isMe: isMe
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMe ? theme.bubbleMe.opacity(0.18) : theme.bubbleOther.opacity(0.18))
                    .cornerRadius(16)
                    .frame(alignment: isMe ? .trailing : .leading)
                    
                    if !isMe {
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if !isMe { Spacer(minLength: 12) }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }
    
    private func formatTime(_ timestamp: TimeInterval) -> String {
        let seconds = timestamp > 100000000000 ? timestamp / 1000 : timestamp
        let date = Date(timeIntervalSince1970: seconds)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return timeFormatter.string(from: date)
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
    let theme: ChatTheme
    @State private var name: String
    @FocusState private var isFocused: Bool
    var onSubmit: (String) -> Void
    
    init(isPresented: Binding<Bool>, theme: ChatTheme, initialName: String, onSubmit: @escaping (String) -> Void) {
        _isPresented = isPresented
        self.theme = theme
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
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.2) : theme.accent)
                        .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .white)
                        .cornerRadius(8)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(theme.surface)
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

struct MessageListView: View {
    let messages: [ChatMessage]
    let userName: String
    let theme: ChatTheme
    
    @State private var userIsDragging = false
    private let bottomAnchorID = "messages-bottom-anchor"
    
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
                    LazyVStack(spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            if shouldShowDate(at: index) {
                                Text(formatDate(message.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            MessageBubble(message: message, isMe: message.user == userName, theme: theme)
                        }
                        // 底部錨點，確保可捲到最底
                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .padding()
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in userIsDragging = true }
                        .onEnded { _ in userIsDragging = false }
                )
                .onAppear {
                    scrollToBottom(proxy)
                }
                .onChange(of: messages.count) { _ in
                    guard !userIsDragging else { return }
                    // 延後執行，確保新訊息完成佈局再滾動
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            scrollToBottom(proxy)
                        }
                    }
                }
            }
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        // 優先滾到底部錨點，確保即使沒有新訊息或資料源異動也能對齊
        withAnimation(.easeOut(duration: 0.18)) {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }
    
    private func shouldShowDate(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentMsg = messages[index]
        let previousMsg = messages[index - 1]
        
        let currentSeconds = currentMsg.timestamp > 100000000000 ? currentMsg.timestamp / 1000 : currentMsg.timestamp
        let previousSeconds = previousMsg.timestamp > 100000000000 ? previousMsg.timestamp / 1000 : previousMsg.timestamp
        
        let currentDate = Date(timeIntervalSince1970: currentSeconds)
        let previousDate = Date(timeIntervalSince1970: previousSeconds)
        
        return !Calendar.current.isDate(currentDate, inSameDayAs: previousDate)
    }
    
    private func formatDate(_ timestamp: TimeInterval) -> String {
        let seconds = timestamp > 100000000000 ? timestamp / 1000 : timestamp
        let date = Date(timeIntervalSince1970: seconds)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - Theme Picker
struct ThemePickerSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedThemeId: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 16) {
                Text("聊天室配色")
                    .font(.title3)
                    .fontWeight(.bold)

                VStack(spacing: 10) {
                    ForEach(ChatTheme.all) { theme in
                        Button {
                            selectedThemeId = theme.id
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(theme.name)
                                        .font(.body)
                                        .fontWeight(.semibold)

                                    HStack(spacing: 6) {
                                        ForEach(Array(theme.swatches.enumerated()), id: \.offset) { _, color in
                                            Circle()
                                                .fill(color)
                                                .frame(width: 16, height: 16)
                                        }
                                    }
                                }

                                Spacer()

                                if selectedThemeId == theme.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(theme.accent)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    }
                }

                Button("關閉") {
                    isPresented = false
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(32)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: isPresented)
    }
}

#Preview {
    ChatView()
}
