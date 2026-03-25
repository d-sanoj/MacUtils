import Foundation

// MARK: - Type-Safe UserDefaults Wrapper

/// Centralized, type-safe access to all UserDefaults settings for Mac Utils.
/// Every stored preference is accessed via a static property on this enum.
public enum Settings {

    private static let defaults = UserDefaults.standard

    // MARK: - General

    public static var launchAtLogin: Bool {
        get { defaults.bool(forKey: "com.macutils.general.launchAtLogin") }
        set { defaults.set(newValue, forKey: "com.macutils.general.launchAtLogin") }
    }

    public static var onboardingCompleted: Bool {
        get { defaults.bool(forKey: "com.macutils.onboarding.completed") }
        set { defaults.set(newValue, forKey: "com.macutils.onboarding.completed") }
    }

    // MARK: - Unformat

    public static var unformatEnabled: Bool {
        get {
            if defaults.object(forKey: "com.macutils.unformat.enabled") == nil {
                return true
            }
            return defaults.bool(forKey: "com.macutils.unformat.enabled")
        }
        set { defaults.set(newValue, forKey: "com.macutils.unformat.enabled") }
    }

    public static var unformatShowNotification: Bool {
        get { defaults.bool(forKey: "com.macutils.unformat.showNotification") }
        set { defaults.set(newValue, forKey: "com.macutils.unformat.showNotification") }
    }



    // MARK: - CtrlPaste

    public static var ctrlPasteEnabled: Bool {
        get {
            if defaults.object(forKey: "com.macutils.ctrlpaste.enabled") == nil {
                return true
            }
            return defaults.bool(forKey: "com.macutils.ctrlpaste.enabled")
        }
        set { defaults.set(newValue, forKey: "com.macutils.ctrlpaste.enabled") }
    }

    public static var ctrlPasteHistory: [String] {
        get { defaults.stringArray(forKey: "com.macutils.ctrlpaste.history") ?? [] }
        set { defaults.set(newValue, forKey: "com.macutils.ctrlpaste.history") }
    }

    public static var ctrlPasteTimestamps: [Double] {
        get { defaults.array(forKey: "com.macutils.ctrlpaste.timestamps") as? [Double] ?? [] }
        set { defaults.set(newValue, forKey: "com.macutils.ctrlpaste.timestamps") }
    }

    // MARK: - Scan

    public static var scanEnabled: Bool {
        get {
            if defaults.object(forKey: "com.macutils.scan.enabled") == nil {
                return true
            }
            return defaults.bool(forKey: "com.macutils.scan.enabled")
        }
        set { defaults.set(newValue, forKey: "com.macutils.scan.enabled") }
    }

    public static var scanShortcut: String {
        get { defaults.string(forKey: "com.macutils.scan.shortcut") ?? "⌘⇧2" }
        set { defaults.set(newValue, forKey: "com.macutils.scan.shortcut") }
    }

    public static var scanAutoAddToCtrlPaste: Bool {
        get {
            if defaults.object(forKey: "com.macutils.scan.autoAddToCtrlPaste") == nil {
                return true
            }
            return defaults.bool(forKey: "com.macutils.scan.autoAddToCtrlPaste")
        }
        set { defaults.set(newValue, forKey: "com.macutils.scan.autoAddToCtrlPaste") }
    }

    public static var scanShowHUD: Bool {
        get {
            if defaults.object(forKey: "com.macutils.scan.showHUD") == nil {
                return true
            }
            return defaults.bool(forKey: "com.macutils.scan.showHUD")
        }
        set { defaults.set(newValue, forKey: "com.macutils.scan.showHUD") }
    }

    // MARK: - Focus

    public static var focusDuration: Int {
        get {
            let val = defaults.integer(forKey: "com.macutils.focus.focusDuration")
            return val > 0 ? val : 25
        }
        set { defaults.set(newValue, forKey: "com.macutils.focus.focusDuration") }
    }

    public static var breakDuration: Int {
        get {
            let val = defaults.integer(forKey: "com.macutils.focus.breakDuration")
            return val > 0 ? val : 5
        }
        set { defaults.set(newValue, forKey: "com.macutils.focus.breakDuration") }
    }

    public static var sessionsPerCycle: Int {
        get {
            let val = defaults.integer(forKey: "com.macutils.focus.sessionsPerCycle")
            return val > 0 ? val : 4
        }
        set { defaults.set(newValue, forKey: "com.macutils.focus.sessionsPerCycle") }
    }

    public static var focusAutoStartBreak: Bool {
        get { defaults.bool(forKey: "com.macutils.focus.autoStartBreak") }
        set { defaults.set(newValue, forKey: "com.macutils.focus.autoStartBreak") }
    }

    public static var focusAutoStartFocus: Bool {
        get { defaults.bool(forKey: "com.macutils.focus.autoStartFocus") }
        set { defaults.set(newValue, forKey: "com.macutils.focus.autoStartFocus") }
    }

    public static var focusSessionsData: Data? {
        get { defaults.data(forKey: "com.macutils.focus.sessions") }
        set { defaults.set(newValue, forKey: "com.macutils.focus.sessions") }
    }

    // MARK: - Glimpse

    private static let sharedDefaults = UserDefaults(suiteName: "com.macutils.shared") ?? .standard

    public static var glimpseDefaultTheme: String {
        get { sharedDefaults.string(forKey: "com.macutils.glimpse.defaultTheme") ?? "github" }
        set {
            sharedDefaults.set(newValue, forKey: "com.macutils.glimpse.defaultTheme")
            defaults.set(newValue, forKey: "com.macutils.glimpse.defaultTheme")
        }
    }

    // MARK: - Lumens

    public static var lumensMapBrightness: Bool {
        get {
            if defaults.object(forKey: "com.macutils.lumens.mapBrightness") == nil {
                return true
            }
            return defaults.bool(forKey: "com.macutils.lumens.mapBrightness")
        }
        set { defaults.set(newValue, forKey: "com.macutils.lumens.mapBrightness") }
    }

    public static var lumensMapVolume: Bool {
        get {
            if defaults.object(forKey: "com.macutils.lumens.mapVolume") == nil {
                return true
            }
            return defaults.bool(forKey: "com.macutils.lumens.mapVolume")
        }
        set { defaults.set(newValue, forKey: "com.macutils.lumens.mapVolume") }
    }
}
