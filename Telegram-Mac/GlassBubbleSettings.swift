//
//  GlassBubbleSettings.swift
//  Glassgram
//
//  User-adjustable look of the Liquid Glass message bubbles.
//  Values are stored in UserDefaults; every change posts `didChange`
//  so visible bubbles update immediately.
//

import Cocoa

struct GlassBubbleSettings: Equatable {
    /// 0 = colorless glass, 1 = solid theme color
    var tintAlpha: CGFloat
    /// Rim brightness at the top edge
    var rimTopAlpha: CGFloat
    /// Rim brightness on the sides
    var rimMiddleAlpha: CGFloat
    /// Rim brightness at the bottom edge
    var rimBottomAlpha: CGFloat

    static let defaults = GlassBubbleSettings(tintAlpha: 0.25, rimTopAlpha: 0.95, rimMiddleAlpha: 0.2, rimBottomAlpha: 0.55)

    static let didChange = Notification.Name("GlassgramGlassBubbleSettingsDidChange")

    private static let storageKey = "glassgram.glassBubbleSettings"
    private static var cached: GlassBubbleSettings?

    /// Current settings. Read and write on the main thread only.
    static var current: GlassBubbleSettings {
        get {
            if let cached = cached {
                return cached
            }
            let loaded = load()
            cached = loaded
            return loaded
        }
        set {
            guard newValue != cached else {
                return
            }
            cached = newValue
            save(newValue)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    private static func load() -> GlassBubbleSettings {
        guard let dict = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Double] else {
            return defaults
        }
        func value(_ key: String, _ fallback: CGFloat) -> CGFloat {
            return dict[key].map { CGFloat($0) } ?? fallback
        }
        return GlassBubbleSettings(tintAlpha: value("tint", defaults.tintAlpha),
                                   rimTopAlpha: value("rimTop", defaults.rimTopAlpha),
                                   rimMiddleAlpha: value("rimMiddle", defaults.rimMiddleAlpha),
                                   rimBottomAlpha: value("rimBottom", defaults.rimBottomAlpha))
    }

    private static func save(_ settings: GlassBubbleSettings) {
        let dict: [String: Double] = [
            "tint": Double(settings.tintAlpha),
            "rimTop": Double(settings.rimTopAlpha),
            "rimMiddle": Double(settings.rimMiddleAlpha),
            "rimBottom": Double(settings.rimBottomAlpha)
        ]
        UserDefaults.standard.set(dict, forKey: storageKey)
    }
}
