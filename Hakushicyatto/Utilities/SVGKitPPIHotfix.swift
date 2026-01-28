//
//  SVGKitPPIHotfix.swift
//  Hakushicyatto
//
//  Workaround for SVGKit 3.0.0 assertion in SVGLength.pixelsPerInchForCurrentDevice
//  on newer / unrecognized devices. We replace the class method to return a sane
//  fallback PPI derived from UIScreen scale.
//

import Foundation
import UIKit
import SVGKit
import ObjectiveC.runtime

/// Install once at app launch before any SVG rendering.
func installSVGKitPPIHotfix() {
    struct Holder { static var installed = false }
    guard !Holder.installed else { return }
    Holder.installed = true
    
    // 避免觸發 SVGLength 的 +initialize：用字串取類別
    guard
        let cls: AnyClass = NSClassFromString("SVGLength"),
        let original = class_getClassMethod(cls, NSSelectorFromString("pixelsPerInchForCurrentDevice"))
    else {
        return
    }
    
    let replacementBlock: @convention(block) (AnyClass) -> CGFloat = { _ in
        // Base PPI 160 (old iPhone @1x), scale it for current screen
        let base: CGFloat = 160
        let scale = currentScreenScale()
        return base * scale
    }
    
    let imp = imp_implementationWithBlock(replacementBlock as Any)
    method_setImplementation(original, imp)
}

/// Safe way to get a screen scale without using deprecated `UIScreen.main` on iOS 26+
private func currentScreenScale() -> CGFloat {
    if let screen = UIApplication.shared
        .connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.screen })
        .first {
        return screen.scale
    }
    // Fallback for early app launch or if no window scene is active yet
    return UIScreen.main.scale
}
