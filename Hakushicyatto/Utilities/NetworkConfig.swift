// 
// NetworkConfig.swift
// Hakushicyatto
//
// Created by 張庭瑄 on 2026/1/28.
//

import Foundation

struct NetworkConfig {
    /// Party.js WebSocket 伺服器 URL (Cloudflare Workers)
    /// - 所有環境使用 wss://hakushicyatto-backend.doliy4784.workers.dev
    static var partyWSURL: String {
        return "wss://hakushicyatto-backend.doliy4784.workers.dev"
    }
    
    /// 設置自訂 Party.js WebSocket URL（用於開發環境）
    static func setPartyWSURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "partyWSURL")
    }
    
    /// 獲取 HTTP API 基礎 URL
    static var apiBaseURL: String {
        return "https://hakushicyatto-backend.doliy4784.workers.dev"
    }
}
