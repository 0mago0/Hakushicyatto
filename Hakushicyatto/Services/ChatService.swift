//
//  ChatService.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/1/28.
//

import Foundation
import Combine

class ChatService: NSObject, ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isConnected: Bool = false
    @Published var error: String?
    @Published var room: String = UUID().uuidString.prefix(8).lowercased()
    @Published var userName: String = "User"
    
    private var webSocket: URLSessionWebSocketTask?
    private let baseURL: String
    private var userId: String = UUID().uuidString
    private var receiveTask: Task<Void, Never>?
    
    init(baseURL: String = "") {
        self.baseURL = baseURL.isEmpty ? NetworkConfig.partyWSURL : baseURL
        super.init()
        loadUserDefaults()
    }
    
    // MARK: - User Defaults
    private func loadUserDefaults() {
        if let savedUserId = UserDefaults.standard.string(forKey: "userId") {
            userId = savedUserId
        } else {
            UserDefaults.standard.set(userId, forKey: "userId")
        }
        
        if let savedName = UserDefaults.standard.string(forKey: "userName") {
            userName = savedName
        } else {
            UserDefaults.standard.set(userName, forKey: "userName")
        }
        
        if let savedRoom = UserDefaults.standard.string(forKey: "chatRoom") {
            room = savedRoom
        }
    }
    
    func setUserName(_ name: String) {
        userName = name
        UserDefaults.standard.set(name, forKey: "userName")
    }
    
    func setRoom(_ newRoom: String) {
        room = newRoom
        messages = []
        error = nil
        UserDefaults.standard.set(newRoom, forKey: "chatRoom")
        disconnect()
        connect()
    }

    /// 建立新的房間並立即切換
    func createNewRoom() {
        let newRoomId = String(UUID().uuidString.prefix(8)).lowercased()
        setRoom(newRoomId)
    }
    
    // MARK: - WebSocket Connection
    func connect() {
        // Party.js URL 格式: wss://partykit-server.com/parties/chat/room-id
        let wsURLString = "\(baseURL)/parties/chat/\(room)"
        print("📡 連接到: \(wsURLString)")
        
        guard let wsURL = URL(string: wsURLString) else {
            DispatchQueue.main.async {
                self.error = "無效的 WebSocket URL"
                self.isConnected = false
            }
            return
        }
        
        webSocket = URLSession.shared.webSocketTask(with: wsURL)
        webSocket?.resume()
        
        print("🔄 WebSocket 已創建，開始接收消息...")
        
        receiveMessage()
    }
    
    private func receiveMessage() {
        receiveTask = Task {
            var connected = true
            
            while connected && !Task.isCancelled {
                do {
                    guard let wsTask = webSocket else {
                        DispatchQueue.main.async {
                            self.isConnected = false
                            self.error = "WebSocket 任務未初始化"
                        }
                        break
                    }
                    
                    let message = try await wsTask.receive()
                    
                    // 首次成功接收消息時設置為已連接
                    if !self.isConnected {
                        DispatchQueue.main.async {
                            self.isConnected = true
                            self.error = nil
                            print("✅ WebSocket 已連接")
                        }
                    }
                    
                    switch message {
                    case .string(let text):
                        print("📨 收到消息 (文字): \(text.prefix(100))...")
                        
                        // 嘗試解析消息
                        if !text.isEmpty {
                            do {
                                if let data = text.data(using: .utf8) {
                                    let decoder = JSONDecoder()
                                    let wsMsg = try decoder.decode(WSMessage.self, from: data)
                                    
                                    // 根據消息類型處理
                                    if wsMsg.type == "all" {
                                        // 處理歷史消息列表
                                        if let messages = wsMsg.messages {
                                            print("📋 收到 \(messages.count) 條歷史消息")
                                            for msg in messages {
                                                if let id = msg.id, let user = msg.user {
                                                    DispatchQueue.main.async {
                                                        let chatMsg = ChatMessage(
                                                            id: id,
                                                            content: msg.content ?? "",
                                                            user: user,
                                                            role: msg.role ?? "user",
                                                            timestamp: msg.timestamp ?? Date().timeIntervalSince1970,
                                                            svgs: msg.svgs
                                                        )
                                                        
                                                        if !self.messages.contains(where: { $0.id == chatMsg.id }) {
                                                            self.messages.append(chatMsg)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    } else if let id = wsMsg.id, let user = wsMsg.user {
                                        // 處理單個消息
                                        DispatchQueue.main.async {
                                            let chatMsg = ChatMessage(
                                                id: id,
                                                content: wsMsg.content ?? "",
                                                user: user,
                                                role: wsMsg.role ?? "user",
                                                timestamp: wsMsg.timestamp ?? Date().timeIntervalSince1970,
                                                svgs: wsMsg.svgs
                                            )
                                            
                                            if !self.messages.contains(where: { $0.id == chatMsg.id }) {
                                                self.messages.append(chatMsg)
                                                print("✅ 添加消息: \(chatMsg.user) - \(chatMsg.content)")
                                            }
                                        }
                                    } else {
                                        print("⚠️  消息缺少必需字段或為控制消息: type=\(wsMsg.type ?? "unknown")")
                                    }
                                }
                            } catch {
                                print("⚠️  解析消息失敗: \(error)")
                                print("📝 原始消息: \(text)")
                                // 不中斷連接，繼續接收下一條消息
                            }
                        }
                        
                    case .data(let data):
                        print("📨 收到消息 (二進制): \(data.count) 字節")
                        
                        do {
                            let decoder = JSONDecoder()
                            let wsMsg = try decoder.decode(WSMessage.self, from: data)
                            
                            // 根據消息類型處理
                            if wsMsg.type == "all" {
                                // 處理歷史消息列表
                                if let messages = wsMsg.messages {
                                    print("📋 收到 \(messages.count) 條歷史消息")
                                    for msg in messages {
                                        if let id = msg.id, let user = msg.user {
                                            DispatchQueue.main.async {
                                                let chatMsg = ChatMessage(
                                                    id: id,
                                                    content: msg.content ?? "",
                                                    user: user,
                                                    role: msg.role ?? "user",
                                                    timestamp: msg.timestamp ?? Date().timeIntervalSince1970,
                                                    svgs: msg.svgs
                                                )
                                                
                                                if !self.messages.contains(where: { $0.id == chatMsg.id }) {
                                                    self.messages.append(chatMsg)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else if let id = wsMsg.id, let user = wsMsg.user {
                                // 處理單個消息
                                DispatchQueue.main.async {
                                    let chatMsg = ChatMessage(
                                        id: id,
                                        content: wsMsg.content ?? "",
                                        user: user,
                                        role: wsMsg.role ?? "user",
                                        timestamp: wsMsg.timestamp ?? Date().timeIntervalSince1970,
                                        svgs: wsMsg.svgs
                                    )
                                    
                                    if !self.messages.contains(where: { $0.id == chatMsg.id }) {
                                        self.messages.append(chatMsg)
                                        print("✅ 添加消息: \(chatMsg.user) - \(chatMsg.content)")
                                    }
                                }
                            } else {
                                print("⚠️  二進制消息缺少必需字段或為控制消息: type=\(wsMsg.type ?? "unknown")")
                            }
                        } catch {
                            print("⚠️  解析二進制消息失敗: \(error)")
                            // 不中斷連接，繼續接收下一條消息
                        }
                        
                    @unknown default:
                        print("⚠️  收到未知類型的消息")
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        print("❌ WebSocket 錯誤: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.isConnected = false
                            self.error = "連接已斷開: \(error.localizedDescription)"
                        }
                    }
                    connected = false
                    break
                }
            }
        }
    }
    
    // MARK: - Send Message
    func sendMessage(_ content: String, svgs: [SvgAttachment]? = nil, messageId: String? = nil) async {
        let messageId = messageId ?? UUID().uuidString
        
        let wsMessage = WSMessage(
            type: "add",
            id: messageId,
            content: content,
            user: userName,
            role: "user",
            timestamp: Date().timeIntervalSince1970,
            svgs: svgs
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(wsMessage)
            if let jsonString = String(data: data, encoding: .utf8) {
                try await webSocket?.send(.string(jsonString))
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "發送失敗: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Upload SVG
    func uploadSVG(_ svgData: Data, filename: String, messageId: String) async throws -> SvgAttachment {
        let apiURL = "\(NetworkConfig.apiBaseURL)/api/svg/upload"
        print("📤 上傳 SVG 到: \(apiURL)")
        print("   文件名: \(filename)")
        print("   數據大小: \(svgData.count) 字節")
        
        guard let url = URL(string: apiURL) else {
            throw NSError(domain: "Invalid URL", code: -1)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add room field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"room\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(room)\r\n".data(using: .utf8)!)
        
        // Add user field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userName)\r\n".data(using: .utf8)!)
        
        // Add messageId field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"messageId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(messageId)\r\n".data(using: .utf8)!)
        
        // Add SVG file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"svgs\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/svg+xml\r\n\r\n".data(using: .utf8)!)
        body.append(svgData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("📥 收到上傳響應: \(response)")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("   狀態碼: \(httpResponse.statusCode)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ 上傳失敗: \(errorMsg)")
                throw NSError(domain: "Upload failed", code: -1)
            }
            
            let responseStr = String(data: data, encoding: .utf8) ?? "invalid"
            print("📋 上傳響應內容: \(responseStr)")
            
            let result = try JSONDecoder().decode([String: [SvgAttachment]].self, from: data)
            guard let svgAttachments = result["svgs"], let attachment = svgAttachments.first else {
                print("❌ 響應中沒有 SVG 附件")
                throw NSError(domain: "No SVG in response", code: -1)
            }

            // 確保檔案已可讀取，避免第一張剛上傳就讀不到
            try await waitUntilSVGReachable(attachment: attachment)
            
            print("✅ SVG 上傳成功!")
            print("   SVG ID: \(attachment.id)")
            print("   SVG URL: \(attachment.url)")
            print("   完整 URL: https://hakushicyatto-backend.doliy4784.workers.dev\(attachment.url)")
            print("   SVG 文件名: \(attachment.filename)")
            
            return attachment
        } catch {
            print("❌ SVG 上傳錯誤: \(error)")
            throw error
        }
    }

    /// Cloudflare R2 可能有輕微延遲，輪詢直到檔案可讀，提升首張 SVG 成功率
    private func waitUntilSVGReachable(attachment: SvgAttachment, maxAttempts: Int = 4) async throws {
        let fullURL = fullSVGURL(attachment.url)
        var attempt = 0

        while attempt < maxAttempts {
            do {
                var request = URLRequest(url: fullURL)
                request.httpMethod = "HEAD"
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    return
                }
            } catch {
                // ignore and retry
            }
            attempt += 1
            let delay = UInt64(pow(2.0, Double(attempt - 1)) * 0.4 * 1_000_000_000) // 0.4s,0.8s,1.6s...
            try? await Task.sleep(nanoseconds: delay)
        }

        throw NSError(domain: "SVG not reachable after upload", code: -2)
    }

    private func fullSVGURL(_ relativePath: String) -> URL {
        if relativePath.lowercased().hasPrefix("http://") || relativePath.lowercased().hasPrefix("https://") {
            return URL(string: relativePath)!
        }
        let normalized = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        let urlString = "\(NetworkConfig.apiBaseURL)/\(normalized)"
        return URL(string: urlString)!
    }
    
    // MARK: - Cleanup
    func disconnect() {
        isConnected = false
        receiveTask?.cancel()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }
    
    deinit {
        disconnect()
    }
}
