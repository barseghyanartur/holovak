import Foundation
import SwiftUI

/// Centralized, future-proof UserDefaults-backed settings.
/// Add new persisted properties here — `reset()` clears them all automatically.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    static let didChange = Notification.Name("SettingsDidChange")

    // MARK: - Keys

    private enum Key {
        static let windowFrame   = "settings.windowFrame"
        static let videoHeight   = "settings.videoHeight"
        static let advancedMode  = "settings.advancedMode"
    }

    // MARK: - Defaults

    private static let defaults: [String: Any] = [
        Key.windowFrame:  [Double](),
        Key.videoHeight:  300.0,
        Key.advancedMode: false,
    ]

    // MARK: - Published properties

    @Published var windowFrame: [Double] {
        didSet { UserDefaults.standard.set(windowFrame, forKey: Key.windowFrame) }
    }

    @Published var videoHeight: Double {
        didSet { UserDefaults.standard.set(videoHeight, forKey: Key.videoHeight) }
    }

    @Published var advancedMode: Bool {
        didSet { UserDefaults.standard.set(advancedMode, forKey: Key.advancedMode) }
    }

    // MARK: - Init

    init() {
        let d = UserDefaults.standard
        d.register(defaults: Self.defaults)

        windowFrame  = d.array(forKey: Key.windowFrame)  as? [Double] ?? []

        let storedHeight = d.double(forKey: Key.videoHeight)
        videoHeight  = storedHeight >= 100.0 ? storedHeight : (Self.defaults[Key.videoHeight] as? Double ?? 300.0)

        advancedMode = d.bool(forKey: Key.advancedMode)
    }

    // MARK: - Reset

    func reset() {
        let d = UserDefaults.standard

        windowFrame  = Self.defaults[Key.windowFrame]  as! [Double]
        videoHeight  = Self.defaults[Key.videoHeight]  as! Double
        advancedMode = Self.defaults[Key.advancedMode]  as! Bool

        d.synchronize()
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
