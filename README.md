# Hakushicyatto｜手寫 SVG 聊天室

Hakushicyatto 是一個使用 Swift 製作的 iOS 手寫聊天室 App。  
使用者可以在聊天室中輸入文字，也可以透過手寫板書寫內容，將筆跡轉換成 SVG 後上傳，並在聊天室中顯示手寫訊息。

Demo Video: [https://youtu.be/ETT7GuwoKHw](https://youtu.be/zCp44g1GpPw?si=eoyns7XOo2nsVjE5)
## 專案動機

一般聊天室大多以文字輸入為主，但在教學、筆記、語言學習或手寫練習情境中，使用者可能需要保留「手寫筆跡」本身。

因此本專案希望實作一個可以將手寫內容數位化的聊天工具，讓使用者能夠在即時聊天中傳送自己的手寫字，並以 SVG 格式保存與顯示。

## 主要功能

- 使用者名稱設定
- 房間 ID 連線與加入房間
- 文字訊息傳送
- 手寫板輸入
- 筆跡轉換為 SVG
- SVG 上傳與聊天室內預覽
- 多個 SVG 可附加於同一則訊息
- 聊天配色主題切換
- 房間紀錄、收藏與刪除
- 訊息時間與日期顯示
- SVG 載入失敗自動重試

## 技術使用

- Swift
- SwiftUI
- PencilKit
- WebSocket
- SVGKit
- URLSession
- AppStorage
- Codable
- MVVM-style structure

## 專案架構

```text
Hakushicyatto/
├── Models/
│   ├── Message.swift
│   └── StrokePoint.swift
│
├── Services/
│   └── ChatService.swift
│
├── Views/
│   ├── Screens/
│   │   ├── ChatView.swift
│   │   ├── DrawingSheet.swift
│   │   └── PairingSheet.swift
│   │
│   └── Components/
│       ├── PKCanvasViewWrapper.swift
│       └── SimpleSVGView.swift
│
├── ContentView.swift
└── HakushicyattoApp.swift
