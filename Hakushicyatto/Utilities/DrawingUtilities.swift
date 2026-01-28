//
//  DrawingUtilities.swift
//  Hakushicyatto
//
//  Created by 張庭瑄 on 2026/1/28.
//

import Foundation
import PencilKit
import UIKit

// MARK: - SVG Export
func exportPKDrawingToSVG(_ drawing: PKDrawing, canvasSize: CGSize) -> String {
    let strokes = drawing.strokes
    guard !strokes.isEmpty else {
        let w = Int(canvasSize.width)
        let h = Int(canvasSize.height)
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="\(w)" height="\(h)" viewBox="0 0 \(w) \(h)" xmlns="http://www.w3.org/2000/svg"></svg>
        """
    }
    
    // 1) Compute bounds of all points
    var minX = CGFloat.greatestFiniteMagnitude
    var minY = CGFloat.greatestFiniteMagnitude
    var maxX = -CGFloat.greatestFiniteMagnitude
    var maxY = -CGFloat.greatestFiniteMagnitude
    
    for stroke in strokes {
        let path = stroke.path
        for i in 0..<path.count {
            let p = path[i].location
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }
    }
    
    let contentWidth = max(maxX - minX, 1)
    let contentHeight = max(maxY - minY, 1)
    
    let targetW = Double(canvasSize.width)
    let targetH = Double(canvasSize.height)
    let scale = min(targetW / Double(contentWidth), targetH / Double(contentHeight))
    
    let offsetX = (targetW - Double(contentWidth) * scale) / 2.0 - Double(minX) * scale
    let offsetY = (targetH - Double(contentHeight) * scale) / 2.0 - Double(minY) * scale
    
    func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
    
    var svgPaths: [String] = []
    
    for stroke in strokes {
        let path = stroke.path
        var pathData = ""
        var isFirstPoint = true
        
        for i in 0..<path.count {
            let p = path[i].location
            let x = Double(p.x) * scale + offsetX
            let y = Double(p.y) * scale + offsetY
            let cmd = isFirstPoint ? "M" : "L"
            pathData += "\(cmd)\(fmt(x)) \(fmt(y))"
            isFirstPoint = false
        }
        
        if !pathData.isEmpty {
            svgPaths.append(pathData)
        }
    }
    
    let strokeWidth = max(1.0, 2.0 * scale) // scale stroke width with drawing
    let width = Int(canvasSize.width)
    let height = Int(canvasSize.height)
    
    var svg = """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)" xmlns="http://www.w3.org/2000/svg">
    """
    
    for pathData in svgPaths {
        svg += """
        
          <path d="\(pathData)" stroke="black" stroke-width="\(fmt(strokeWidth))" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
        """
    }
    
    svg += """
    
    </svg>
    """
    
    return svg
}
