//
//  ChatTheme.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/2/7.
//

import SwiftUI

struct ChatTheme: Identifiable {
    let id: String
    let name: String
    let background: Color
    let surface: Color
    let accent: Color
    let bubbleMe: Color
    let bubbleOther: Color
    let onBackground: Color
    let onSurface: Color

    var swatches: [Color] {
        [background, surface, accent, bubbleMe]
    }

    static let classic = ChatTheme(
        id: "classic",
        name: "經典",
        background: Color(.systemBackground),
        surface: Color(.secondarySystemBackground),
        accent: .blue,
        bubbleMe: .blue,
        bubbleOther: .gray,
        onBackground: .primary,
        onSurface: .primary
    )

    static let moss = ChatTheme(
        id: "moss",
        name: "森霧",
        background: Color(hex: "E8E2D8"),
        surface: Color(hex: "BFC6C4"),
        accent: Color(hex: "F2A65A"),
        bubbleMe: Color(hex: "6F8F72"),
        bubbleOther: Color(hex: "BFC6C4"),
        onBackground: .black,
        onSurface: .black
    )

    static let blossom = ChatTheme(
        id: "blossom",
        name: "花糖",
        background: Color(hex: "F0FFDF"),
        surface: Color(hex: "A8DF8E"),
        accent: Color(hex: "FFAAB8"),
        bubbleMe: Color(hex: "FFD8DF"),
        bubbleOther: Color(hex: "A8DF8E"),
        onBackground: .black,
        onSurface: .black
    )

    static let ocean = ChatTheme(
        id: "ocean",
        name: "深海",
        background: Color(hex: "BDE8F5"),
        surface: Color(hex: "4988C4"),
        accent: Color(hex: "1C4D8D"),
        bubbleMe: Color(hex: "4988C4"),
        bubbleOther: Color(hex: "0F2854"),
        onBackground: .black,
        onSurface: .white
    )

    static let all: [ChatTheme] = [classic, moss, blossom, ocean]

    static func theme(for id: String) -> ChatTheme {
        all.first { $0.id == id } ?? classic
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        default:
            r = 0
            g = 0
            b = 0
        }

        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
