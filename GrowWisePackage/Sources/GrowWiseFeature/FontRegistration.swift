import CoreText
import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public enum FontRegistration {
    private static let logger = Logger(subsystem: "com.growwise", category: "FontRegistration")
    private static var registered = false

    public static func registerIfNeeded() {
        guard !registered else { return }
        registered = true
        let names = [
            "Fraunces[SOFT,WONK,opsz,wght]",
            "Fraunces-Italic[SOFT,WONK,opsz,wght]",
            "Manrope[wght]",
        ]
        for name in names {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else {
                logger.error("Font missing from bundle: \(name, privacy: .public)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                logger.error("Font register failed: \(name, privacy: .public) — \(String(describing: error), privacy: .public)")
            }
        }
    }

    #if canImport(UIKit)
    public static var frauncesAvailable: Bool {
        UIFont.familyNames.contains("Fraunces")
    }

    public static var manropeAvailable: Bool {
        UIFont.familyNames.contains("Manrope")
    }
    #else
    public static var frauncesAvailable: Bool {
        false
    }

    public static var manropeAvailable: Bool {
        false
    }
    #endif
}
