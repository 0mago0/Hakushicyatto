//
//  StrokePoint.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/1/28.
//

import Foundation

struct StrokePoint: Codable {
    let x: CGFloat
    let y: CGFloat
    let pressure: CGFloat
    
    enum CodingKeys: String, CodingKey {
        case x, y, pressure
    }
}
