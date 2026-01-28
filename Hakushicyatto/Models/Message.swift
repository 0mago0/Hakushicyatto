//
//  Message.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/1/28.
//

import Foundation

// MARK: - SVG Attachment
struct SvgAttachment: Identifiable, Codable {
    let id: String
    let filename: String
    let url: String
}

extension SvgAttachment: Hashable {
    static func == (lhs: SvgAttachment, rhs: SvgAttachment) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case filename
        case url
    }
}

// MARK: - Chat Message (應用內)
struct ChatMessage: Identifiable, Codable {
    let id: String
    let content: String
    let user: String
    let role: String
    let timestamp: TimeInterval
    let svgs: [SvgAttachment]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case user
        case role
        case timestamp
        case svgs
    }
}

// MARK: - WebSocket Message (黨.js 協議)
struct WSMessage: Codable {
    let type: String?  // "add", "update", "init", "all"
    let id: String?
    let content: String?
    let user: String?
    let role: String?
    let timestamp: TimeInterval?
    let svgs: [SvgAttachment]?
    let messages: [WSMessage]?  // 用於 "all" 類型消息
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case content
        case user
        case role
        case timestamp
        case svgs
        case messages
    }
    
    // 便利初始化器，用於創建消息
    init(type: String? = nil, id: String? = nil, content: String? = nil, user: String? = nil, role: String? = nil, timestamp: TimeInterval? = nil, svgs: [SvgAttachment]? = nil, messages: [WSMessage]? = nil) {
        self.type = type
        self.id = id
        self.content = content
        self.user = user
        self.role = role
        self.timestamp = timestamp
        self.svgs = svgs
        self.messages = messages
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        user = try container.decodeIfPresent(String.self, forKey: .user)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        timestamp = try container.decodeIfPresent(TimeInterval.self, forKey: .timestamp)
        svgs = try container.decodeIfPresent([SvgAttachment].self, forKey: .svgs)
        messages = try container.decodeIfPresent([WSMessage].self, forKey: .messages)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(svgs, forKey: .svgs)
        try container.encodeIfPresent(messages, forKey: .messages)
    }
}
